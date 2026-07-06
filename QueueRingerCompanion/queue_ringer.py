import argparse
import ctypes
import json
import os
import queue
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
from dataclasses import dataclass

import tkinter as tk
from tkinter import filedialog, messagebox, scrolledtext, ttk

DEPENDENCY_ERROR = None

try:
    import cv2
    import numpy as np
    from PIL import Image, ImageDraw, ImageFont, ImageGrab, ImageTk
except Exception as exc:
    cv2 = None
    np = None
    Image = None
    ImageDraw = None
    ImageFont = None
    ImageGrab = None
    ImageTk = None
    DEPENDENCY_ERROR = exc

try:
    import pystray
except Exception:
    pystray = None


SCRIPT_DIR = os.path.dirname(__file__)
CONFIG_PATH = os.path.join(SCRIPT_DIR, "config.json")
CONFIG_EXAMPLE_PATH = os.path.join(SCRIPT_DIR, "config.example.json")
STATE_PATH = os.path.join(SCRIPT_DIR, "state.json")
APP_TITLE = "BenTools Queue Ringer"
WOW_TITLE_HINT = "World of Warcraft"
START_BATCH_NAME = "Start Queue Ringer.bat"
LAUNCH_BATCH_NAME = "Launch WoW with Queue Ringer.bat"
STARTUP_SHORTCUT_NAME = "BenTools Queue Ringer.lnk"
SINGLE_INSTANCE_MUTEX = "Local\\BenToolsQueueRingerCompanion"


def load_json(path, default):
    if not os.path.exists(path):
        return default
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def save_json(path, payload):
    temp_path = path + ".tmp"
    with open(temp_path, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2, sort_keys=True)
    os.replace(temp_path, path)


def mask_webhook(url):
    if not url:
        return "(missing)"
    if len(url) < 16:
        return "***"
    return url[:8] + "..." + url[-6:]


def load_config():
    config = load_json(CONFIG_PATH, None)
    if config is None:
        example = load_json(CONFIG_EXAMPLE_PATH, None)
        if example is not None:
            save_json(CONFIG_PATH, example)
            config = load_json(CONFIG_PATH, None)
        if config is None:
            raise FileNotFoundError(
                f"Missing config file: {CONFIG_PATH}. Copy config.example.json to config.json and fill it in."
            )
    config.setdefault("enabled", True)
    config.setdefault("discordWebhookUrl", "")
    config.setdefault("mention", "")
    config.setdefault("pollIntervalMs", 350)
    config.setdefault("cooldownSeconds", 45)
    config.setdefault("matchThreshold", 0.88)
    config.setdefault("confirmFrames", 2)
    config.setdefault("saveDebugFrame", False)
    config.setdefault("startWithWindows", False)
    config.setdefault("startWatchingAutomatically", False)
    config.setdefault("startMinimized", False)
    config.setdefault("gameLauncherPath", "")
    return config


def load_state():
    return load_json(
        STATE_PATH,
        {
            "lastDetectedAt": 0,
            "lastNotificationAt": 0,
            "lastScore": 0.0,
            "lastWindowTitle": "",
        },
    )


def build_discord_payload(mention):
    payload = {
        "content": mention or "",
        "embeds": [
            {
                "title": "WoW Queue Ready!",
                "description": "BenTools Queue Ringer spotted the in-game ready banner.\n\nYour queue is ready. Jump back in.",
                "color": 16766720,
                "footer": {"text": "BenTools Queue Ringer"},
                "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time())),
            }
        ],
    }
    return payload


def send_webhook(config, payload, log_fn):
    webhook_url = config.get("discordWebhookUrl", "")
    if not webhook_url:
        raise RuntimeError("Discord webhook URL is missing from config.json")

    request = urllib.request.Request(
        webhook_url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json", "User-Agent": "BenTools-QueueRinger/2.1"},
        method="POST",
    )

    last_error = None
    for attempt in range(1, 4):
        try:
            with urllib.request.urlopen(request, timeout=10) as response:
                status = getattr(response, "status", response.getcode())
                if status in (200, 204):
                    log_fn(f"Discord notification sent successfully (HTTP {status}).")
                    return
                last_error = RuntimeError(f"Unexpected webhook response: HTTP {status}")
        except urllib.error.HTTPError as exc:
            if exc.code == 429:
                retry_after = exc.headers.get("Retry-After")
                delay = float(retry_after) if retry_after else 2.0
                log_fn(f"Discord rate limited the request; retrying in {delay:.1f}s.")
                time.sleep(delay)
                last_error = exc
                continue
            last_error = exc
        except Exception as exc:
            last_error = exc

        if attempt < 3:
            time.sleep(1.5 * attempt)

    raise last_error


def make_beacon_template(scale=1.0):
    width = max(40, int(132 * scale))
    height = max(10, int(18 * scale))
    image = np.zeros((height, width, 3), dtype=np.uint8)
    image[:, :] = (15, 8, 5)

    palette = [
        (46, 115, 247),
        (237, 212, 36),
        (247, 84, 171),
        (63, 209, 252),
        (135, 74, 245),
    ]
    block_width = max(10, int(20 * scale))
    block_height = max(6, int(10 * scale))
    spacing = max(2, int(4 * scale))
    left = max(4, int(8 * scale))
    top = max(2, int((height - block_height) / 2))

    for color in palette:
        right = min(width - 1, left + block_width)
        bottom = min(height - 1, top + block_height)
        image[top:bottom, left:right] = color
        left = right + spacing

    return image


@dataclass
class WindowInfo:
    title: str
    left: int
    top: int
    right: int
    bottom: int

    @property
    def width(self):
        return self.right - self.left

    @property
    def height(self):
        return self.bottom - self.top


class SingleInstanceGuard:
    def __init__(self, name):
        self.name = name
        self.handle = None

    def acquire(self):
        kernel32 = ctypes.windll.kernel32
        self.handle = kernel32.CreateMutexW(None, False, self.name)
        already_exists = kernel32.GetLastError() == 183
        return not already_exists

    def release(self):
        if self.handle:
            ctypes.windll.kernel32.CloseHandle(self.handle)
            self.handle = None


def hide_console_window():
    kernel32 = ctypes.windll.kernel32
    user32 = ctypes.windll.user32
    hwnd = kernel32.GetConsoleWindow()
    if hwnd:
        user32.ShowWindow(hwnd, 0)


def find_wow_window():
    from ctypes import wintypes

    user32 = ctypes.windll.user32
    found = []

    EnumWindowsProc = ctypes.WINFUNCTYPE(ctypes.c_bool, wintypes.HWND, wintypes.LPARAM)

    def callback(hwnd, _):
        if not user32.IsWindowVisible(hwnd):
            return True
        length = user32.GetWindowTextLengthW(hwnd)
        if length <= 0:
            return True
        buffer = ctypes.create_unicode_buffer(length + 1)
        user32.GetWindowTextW(hwnd, buffer, length + 1)
        title = buffer.value
        if WOW_TITLE_HINT.lower() not in title.lower():
            return True

        rect = wintypes.RECT()
        if not user32.GetWindowRect(hwnd, ctypes.byref(rect)):
            return True
        if rect.right - rect.left < 300 or rect.bottom - rect.top < 200:
            return True

        found.append(WindowInfo(title, rect.left, rect.top, rect.right, rect.bottom))
        return False

    user32.EnumWindows(EnumWindowsProc(callback), 0)
    return found[0] if found else None


def capture_roi(window_info):
    top = window_info.top + int(window_info.height * 0.04)
    bottom = window_info.top + int(window_info.height * 0.28)
    left = window_info.left + int(window_info.width * 0.45)
    right = window_info.left + int(window_info.width * 0.98)
    bbox = (left, top, right, bottom)

    image = ImageGrab.grab(bbox=bbox, all_screens=True)
    frame_rgb = np.array(image)
    frame_bgr = cv2.cvtColor(frame_rgb, cv2.COLOR_RGB2BGR)
    return bbox, frame_bgr, image


def detect_beacon(frame_bgr):
    best_score = 0.0
    best_rect = None

    for scale in (0.80, 0.90, 1.0, 1.10, 1.20, 1.35):
        template = make_beacon_template(scale)
        if template.shape[0] >= frame_bgr.shape[0] or template.shape[1] >= frame_bgr.shape[1]:
            continue
        result = cv2.matchTemplate(frame_bgr, template, cv2.TM_CCOEFF_NORMED)
        _, score, _, point = cv2.minMaxLoc(result)
        if score > best_score:
            best_score = float(score)
            best_rect = (point[0], point[1], template.shape[1], template.shape[0])

    return best_score, best_rect


def get_startup_folder():
    appdata = os.environ.get("APPDATA", "")
    if not appdata:
        raise RuntimeError("APPDATA is not available for the current user.")
    return os.path.join(appdata, "Microsoft", "Windows", "Start Menu", "Programs", "Startup")


def get_startup_shortcut_path():
    return os.path.join(get_startup_folder(), STARTUP_SHORTCUT_NAME)


def powershell_literal(text):
    return "'" + str(text).replace("'", "''") + "'"


def is_startup_enabled():
    return os.path.exists(get_startup_shortcut_path())


def ensure_startup_shortcut(enabled):
    shortcut_path = get_startup_shortcut_path()
    if not enabled:
        if os.path.exists(shortcut_path):
            os.remove(shortcut_path)
        return False

    batch_path = os.path.join(SCRIPT_DIR, START_BATCH_NAME)
    if not os.path.exists(batch_path):
        raise RuntimeError(f"Missing launcher batch file: {batch_path}")

    command = (
        f"$ws = New-Object -ComObject WScript.Shell; "
        f"$s = $ws.CreateShortcut({powershell_literal(shortcut_path)}); "
        f"$s.TargetPath = {powershell_literal(batch_path)}; "
        f"$s.WorkingDirectory = {powershell_literal(SCRIPT_DIR)}; "
        f"$s.WindowStyle = 7; "
        f"$s.IconLocation = {powershell_literal(batch_path + ',0')}; "
        f"$s.Save()"
    )
    result = subprocess.run(
        ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", command],
        capture_output=True,
        text=True,
        timeout=15,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "Could not create the startup shortcut.")
    return True


def resolve_default_game_targets():
    candidates = []
    for root in filter(None, [os.environ.get("ProgramFiles(x86)"), os.environ.get("ProgramFiles")]):
        candidates.extend(
            [
                os.path.join(root, "Battle.net", "Battle.net Launcher.exe"),
                os.path.join(root, "World of Warcraft", "World of Warcraft Launcher.exe"),
                os.path.join(root, "World of Warcraft", "_retail_", "Wow.exe"),
                os.path.join(root, "World of Warcraft", "_retail_", "WowT.exe"),
            ]
        )
    return candidates


def resolve_game_launch_path(config):
    configured = (config.get("gameLauncherPath", "") or "").strip()
    if configured:
        if os.path.exists(configured):
            return configured
        raise FileNotFoundError(f"Configured game path was not found: {configured}")

    for candidate in resolve_default_game_targets():
        if os.path.exists(candidate):
            return candidate

    raise FileNotFoundError(
        "Could not find World of Warcraft or Battle.net automatically. Set a path in the Queue Ringer companion."
    )


def launch_game_target(config):
    target_path = resolve_game_launch_path(config)
    subprocess.Popen([target_path], cwd=os.path.dirname(target_path))
    return target_path


class Watcher(threading.Thread):
    def __init__(self, config, state, event_queue):
        super().__init__(daemon=True)
        self.config = config
        self.state = state
        self.event_queue = event_queue
        self.stop_event = threading.Event()
        self.notified_for_signal = False
        self.consecutive_matches = 0
        self.consecutive_misses = 0

    def emit(self, kind, payload=None):
        self.event_queue.put((kind, payload or {}))

    def run(self):
        self.emit("log", {"message": f"Watcher started. Webhook configured: {mask_webhook(self.config.get('discordWebhookUrl', ''))}"})
        poll_interval = max(100, int(self.config.get("pollIntervalMs", 350) or 350)) / 1000.0
        threshold = float(self.config.get("matchThreshold", 0.88) or 0.88)
        confirm_frames = max(1, int(self.config.get("confirmFrames", 2) or 2))
        cooldown = max(10, int(self.config.get("cooldownSeconds", 45) or 45))

        while not self.stop_event.is_set():
            try:
                window_info = find_wow_window()
                if not window_info:
                    self.emit("status", {"wow": "not_found"})
                    self.consecutive_matches = 0
                    self.consecutive_misses += 1
                    time.sleep(poll_interval)
                    continue

                self.state["lastWindowTitle"] = window_info.title
                self.emit("status", {"wow": "found", "title": window_info.title})

                _, frame_bgr, frame_image = capture_roi(window_info)
                score, rect = detect_beacon(frame_bgr)
                self.state["lastScore"] = score
                self.emit("score", {"score": score, "rect": rect})

                if score >= threshold:
                    self.consecutive_matches += 1
                    self.consecutive_misses = 0
                    if self.consecutive_matches >= confirm_frames:
                        self.state["lastDetectedAt"] = int(time.time())
                        self.emit("status", {"detector": "match"})
                        if not self.notified_for_signal:
                            now = int(time.time())
                            last_notification = int(self.state.get("lastNotificationAt", 0) or 0)
                            if last_notification and now - last_notification < cooldown:
                                self.emit("log", {"message": "Queue banner detected again, but still inside cooldown window."})
                                self.notified_for_signal = True
                            else:
                                payload = build_discord_payload(self.config.get("mention", ""))
                                send_webhook(self.config, payload, lambda message: self.emit("log", {"message": message}))
                                self.state["lastNotificationAt"] = now
                                save_json(STATE_PATH, self.state)
                                self.notified_for_signal = True
                                self.emit("log", {"message": "Queue banner confirmed. Discord notification sent."})
                                self.emit("notified", {})

                                if self.config.get("saveDebugFrame"):
                                    debug_path = os.path.join(SCRIPT_DIR, "last_detection.png")
                                    frame_image.save(debug_path)
                                    self.emit("log", {"message": f"Saved debug frame to {debug_path}"})
                else:
                    self.consecutive_matches = 0
                    self.consecutive_misses += 1
                    self.emit("status", {"detector": "clear"})
                    if self.consecutive_misses >= 3:
                        self.notified_for_signal = False

                save_json(STATE_PATH, self.state)
            except Exception as exc:
                self.emit("log", {"message": f"Watcher error: {exc}"})

            time.sleep(poll_interval)

        self.emit("log", {"message": "Watcher stopped."})

    def stop(self):
        self.stop_event.set()


class QueueRingerApp:
    def __init__(self, root, config, state):
        self.root = root
        self.config = config
        self.state = state
        self.event_queue = queue.Queue()
        self.watcher = None
        self.preview_image = None
        self.startup_actual = is_startup_enabled()
        self.tray_icon = None
        self.tray_thread = None
        self.tray_ready = pystray is not None
        self.is_hidden_to_tray = False

        if self.config.get("startWithWindows", False) != self.startup_actual:
            self.config["startWithWindows"] = self.startup_actual
            save_json(CONFIG_PATH, self.config)

        self.root.title(APP_TITLE)
        self.root.geometry("920x760")
        self.root.minsize(860, 700)
        self.root.configure(bg="#0c111b")
        self.root.protocol("WM_DELETE_WINDOW", self.on_close)

        self.style = ttk.Style()
        try:
            self.style.theme_use("clam")
        except Exception:
            pass
        self.style.configure("Card.TFrame", background="#111827")
        self.style.configure("Title.TLabel", background="#111827", foreground="#f8fafc", font=("Segoe UI", 18, "bold"))
        self.style.configure("Muted.TLabel", background="#111827", foreground="#94a3b8", font=("Segoe UI", 10))
        self.style.configure("Value.TLabel", background="#111827", foreground="#e2e8f0", font=("Segoe UI", 11, "bold"))
        self.style.configure("TLabel", background="#0c111b", foreground="#e5e7eb", font=("Segoe UI", 10))
        self.style.configure("TButton", font=("Segoe UI", 10, "bold"), padding=8)
        self.style.configure("Header.TLabel", background="#0c111b", foreground="#f8fafc", font=("Segoe UI", 11, "bold"))
        self.style.configure("TCheckbutton", background="#111827", foreground="#e5e7eb", font=("Segoe UI", 10))
        self.style.configure("TEntry", padding=6)

        self.build_ui()
        self.refresh_status_labels()
        self.root.after(150, self.process_events)
        self.root.after(350, self.apply_startup_preferences)
        self.setup_tray()

    def build_ui(self):
        outer = ttk.Frame(self.root, padding=18, style="Card.TFrame")
        outer.pack(fill="both", expand=True, padx=16, pady=16)

        header = ttk.Frame(outer, style="Card.TFrame")
        header.pack(fill="x")
        ttk.Label(header, text="BenTools Queue Ringer", style="Title.TLabel").pack(anchor="w")
        ttk.Label(
            header,
            text="Watches the bright BenTools queue banner in the WoW window and pushes Discord alerts to your phone.",
            style="Muted.TLabel",
        ).pack(anchor="w", pady=(6, 0))

        controls = ttk.Frame(outer, style="Card.TFrame")
        controls.pack(fill="x", pady=(18, 10))

        left = ttk.Frame(controls, style="Card.TFrame")
        left.pack(side="left", fill="both", expand=True)
        left.columnconfigure(0, weight=1)

        ttk.Label(left, text="Discord webhook", style="Header.TLabel").grid(row=0, column=0, sticky="w")
        self.webhook_var = tk.StringVar(value=self.config.get("discordWebhookUrl", ""))
        ttk.Entry(left, textvariable=self.webhook_var, width=72).grid(row=1, column=0, sticky="ew", pady=(6, 10))

        ttk.Label(left, text="Mention (optional)", style="Header.TLabel").grid(row=2, column=0, sticky="w")
        self.mention_var = tk.StringVar(value=self.config.get("mention", ""))
        ttk.Entry(left, textvariable=self.mention_var, width=36).grid(row=3, column=0, sticky="w", pady=(6, 10))

        ttk.Label(left, text="WoW / Battle.net path (optional)", style="Header.TLabel").grid(row=4, column=0, sticky="w")
        launcher_row = ttk.Frame(left, style="Card.TFrame")
        launcher_row.grid(row=5, column=0, sticky="ew", pady=(6, 10))
        launcher_row.columnconfigure(0, weight=1)
        self.game_path_var = tk.StringVar(value=self.config.get("gameLauncherPath", ""))
        ttk.Entry(launcher_row, textvariable=self.game_path_var).grid(row=0, column=0, sticky="ew")
        ttk.Button(launcher_row, text="Browse", command=self.browse_game_path).grid(row=0, column=1, padx=(8, 0))

        row = ttk.Frame(left, style="Card.TFrame")
        row.grid(row=6, column=0, sticky="w")

        self.threshold_var = tk.StringVar(value=str(self.config.get("matchThreshold", 0.88)))
        self.cooldown_var = tk.StringVar(value=str(self.config.get("cooldownSeconds", 45)))
        self.poll_var = tk.StringVar(value=str(self.config.get("pollIntervalMs", 350)))

        for label_text, variable in (
            ("Match threshold", self.threshold_var),
            ("Cooldown (s)", self.cooldown_var),
            ("Poll (ms)", self.poll_var),
        ):
            group = ttk.Frame(row, style="Card.TFrame")
            group.pack(side="left", padx=(0, 14))
            ttk.Label(group, text=label_text, style="Muted.TLabel").pack(anchor="w")
            ttk.Entry(group, textvariable=variable, width=12).pack(anchor="w", pady=(4, 0))

        toggles = ttk.Frame(left, style="Card.TFrame")
        toggles.grid(row=7, column=0, sticky="w", pady=(14, 0))

        self.startup_var = tk.BooleanVar(value=self.startup_actual)
        self.auto_watch_var = tk.BooleanVar(value=bool(self.config.get("startWatchingAutomatically", False)))
        self.start_minimized_var = tk.BooleanVar(value=bool(self.config.get("startMinimized", False)))

        ttk.Checkbutton(toggles, text="Start Queue Ringer with Windows", variable=self.startup_var).pack(anchor="w")
        ttk.Checkbutton(toggles, text="Start watching automatically", variable=self.auto_watch_var).pack(anchor="w", pady=(6, 0))
        ttk.Checkbutton(toggles, text="Start minimized", variable=self.start_minimized_var).pack(anchor="w", pady=(6, 0))

        right = ttk.Frame(controls, style="Card.TFrame")
        right.pack(side="right", fill="y", padx=(24, 0))

        ttk.Button(right, text="Save", command=self.save_config).pack(fill="x")
        ttk.Button(right, text="Send Discord Test", command=self.send_test).pack(fill="x", pady=(8, 0))
        ttk.Button(right, text="Start Watching", command=self.start_watcher).pack(fill="x", pady=(8, 0))
        ttk.Button(right, text="Stop", command=self.stop_watcher).pack(fill="x", pady=(8, 0))
        ttk.Button(right, text="Capture Preview", command=self.capture_preview).pack(fill="x", pady=(8, 0))
        ttk.Button(right, text="Launch WoW / Battle.net", command=self.launch_game_from_ui).pack(fill="x", pady=(8, 0))

        status_row = ttk.Frame(outer, style="Card.TFrame")
        status_row.pack(fill="x", pady=(8, 12))

        self.status_vars = {
            "watcher": tk.StringVar(value="Idle"),
            "wow": tk.StringVar(value="Looking for WoW"),
            "score": tk.StringVar(value="0.000"),
            "last_notification": tk.StringVar(value="Never"),
            "startup": tk.StringVar(value="Disabled"),
            "tray": tk.StringVar(value="Enabled" if self.tray_ready else "Unavailable"),
        }

        for label_text, key in (
            ("Watcher", "watcher"),
            ("WoW window", "wow"),
            ("Detector score", "score"),
            ("Last phone ping", "last_notification"),
            ("Startup", "startup"),
            ("Tray", "tray"),
        ):
            card = ttk.Frame(status_row, style="Card.TFrame", padding=12)
            card.pack(side="left", fill="both", expand=True, padx=(0, 10))
            ttk.Label(card, text=label_text, style="Muted.TLabel").pack(anchor="w")
            ttk.Label(card, textvariable=self.status_vars[key], style="Value.TLabel").pack(anchor="w", pady=(6, 0))

        body = ttk.Frame(outer, style="Card.TFrame")
        body.pack(fill="both", expand=True)

        preview_card = ttk.Frame(body, style="Card.TFrame")
        preview_card.pack(side="left", fill="both", expand=True)
        ttk.Label(preview_card, text="Detection Preview", style="Header.TLabel").pack(anchor="w")
        ttk.Label(
            preview_card,
            text="This captures the top-center region of the WoW window where the BenTools queue banner appears.",
            style="Muted.TLabel",
        ).pack(anchor="w", pady=(4, 10))
        self.preview_label = ttk.Label(preview_card)
        self.preview_label.pack(fill="both", expand=True)

        log_card = ttk.Frame(body, style="Card.TFrame")
        log_card.pack(side="right", fill="both", expand=True, padx=(14, 0))
        ttk.Label(log_card, text="Activity", style="Header.TLabel").pack(anchor="w")
        self.log_box = scrolledtext.ScrolledText(
            log_card,
            wrap="word",
            height=20,
            bg="#08101a",
            fg="#dbeafe",
            insertbackground="#dbeafe",
            relief="flat",
            font=("Consolas", 10),
        )
        self.log_box.pack(fill="both", expand=True, pady=(10, 0))
        self.log_box.configure(state="disabled")

    def log(self, message):
        timestamp = time.strftime("%H:%M:%S")
        self.log_box.configure(state="normal")
        self.log_box.insert("end", f"[{timestamp}] {message}\n")
        self.log_box.see("end")
        self.log_box.configure(state="disabled")

    def refresh_status_labels(self):
        last_notification = int(self.state.get("lastNotificationAt", 0) or 0)
        if last_notification > 0:
            self.status_vars["last_notification"].set(time.strftime("%I:%M:%S %p", time.localtime(last_notification)))
        else:
            self.status_vars["last_notification"].set("Never")
        self.status_vars["startup"].set("Enabled" if is_startup_enabled() else "Disabled")
        self.status_vars["tray"].set("Enabled" if self.tray_ready else "Unavailable")

    def create_tray_image(self):
        image = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        draw = ImageDraw.Draw(image)

        draw.ellipse((3, 3, 61, 61), fill=(46, 28, 8, 255), outline=(224, 182, 84, 255), width=4)
        draw.ellipse((10, 10, 54, 54), fill=(18, 36, 74, 255), outline=(246, 213, 120, 255), width=2)
        draw.ellipse((16, 16, 48, 48), fill=(29, 61, 118, 255))

        try:
            font = ImageFont.truetype("arialbd.ttf", 24)
        except Exception:
            try:
                font = ImageFont.truetype("segoeuib.ttf", 24)
            except Exception:
                font = ImageFont.load_default()

        text = "BT"
        left, top, right, bottom = draw.textbbox((0, 0), text, font=font)
        text_width = right - left
        text_height = bottom - top
        text_x = (64 - text_width) / 2
        text_y = (64 - text_height) / 2 - 1

        draw.text((text_x + 1, text_y + 1), text, font=font, fill=(60, 28, 8, 255))
        draw.text((text_x, text_y), text, font=font, fill=(255, 230, 156, 255))

        draw.arc((6, 6, 58, 58), start=212, end=320, fill=(255, 243, 186, 255), width=2)
        draw.arc((8, 8, 56, 56), start=25, end=120, fill=(88, 162, 255, 220), width=2)
        return image

    def setup_tray(self):
        if not self.tray_ready:
            return
        image = self.create_tray_image()
        menu = pystray.Menu(
            pystray.MenuItem("Show Queue Ringer", lambda icon, item: self.show_from_tray(), default=True),
            pystray.MenuItem(
                "Start Watching",
                lambda icon, item: self.root.after(0, self.start_watcher),
                enabled=lambda item: not (self.watcher and self.watcher.is_alive()),
            ),
            pystray.MenuItem(
                "Stop Watching",
                lambda icon, item: self.root.after(0, self.stop_watcher),
                enabled=lambda item: self.watcher is not None,
            ),
            pystray.MenuItem("Launch WoW / Battle.net", lambda icon, item: self.root.after(0, self.launch_game_from_ui)),
            pystray.MenuItem("Exit", lambda icon, item: self.root.after(0, self.exit_app)),
        )
        self.tray_icon = pystray.Icon("bentools_queue_ringer", image, APP_TITLE, menu)
        self.tray_thread = threading.Thread(target=self.tray_icon.run, daemon=True)
        self.tray_thread.start()

    def show_from_tray(self):
        self.is_hidden_to_tray = False
        self.root.deiconify()
        self.root.lift()
        self.root.after(50, self.root.focus_force)

    def hide_to_tray(self):
        if not self.tray_ready:
            self.root.iconify()
            return
        self.is_hidden_to_tray = True
        self.root.withdraw()
        self.log("Queue Ringer hidden to system tray.")

    def browse_game_path(self):
        path = filedialog.askopenfilename(
            title="Choose World of Warcraft or Battle.net",
            filetypes=[("Executables", "*.exe"), ("All files", "*.*")],
        )
        if path:
            self.game_path_var.set(path)

    def save_config(self):
        try:
            self.config["discordWebhookUrl"] = self.webhook_var.get().strip()
            self.config["mention"] = self.mention_var.get().strip()
            self.config["gameLauncherPath"] = self.game_path_var.get().strip()
            self.config["matchThreshold"] = float(self.threshold_var.get().strip() or "0.88")
            self.config["cooldownSeconds"] = int(self.cooldown_var.get().strip() or "45")
            self.config["pollIntervalMs"] = int(self.poll_var.get().strip() or "350")
            self.config["startWatchingAutomatically"] = self.auto_watch_var.get()
            self.config["startMinimized"] = self.start_minimized_var.get()
            self.config["startWithWindows"] = self.startup_var.get()
            ensure_startup_shortcut(self.startup_var.get())
            self.config["startWithWindows"] = is_startup_enabled()
            self.startup_var.set(self.config["startWithWindows"])
            save_json(CONFIG_PATH, self.config)
            self.refresh_status_labels()
            self.log("Saved configuration.")
        except Exception as exc:
            self.startup_var.set(is_startup_enabled())
            messagebox.showerror(APP_TITLE, f"Could not save configuration:\n{exc}")

    def send_test(self):
        self.save_config()
        try:
            payload = {
                "content": self.config.get("mention", ""),
                "embeds": [
                    {
                        "title": "Queue Ringer Test",
                        "description": "Your Discord webhook is configured correctly.",
                        "color": 5763719,
                        "footer": {"text": "BenTools Queue Ringer"},
                        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time())),
                    }
                ],
            }
            send_webhook(self.config, payload, self.log)
        except Exception as exc:
            messagebox.showerror(APP_TITLE, f"Discord test failed:\n{exc}")

    def start_watcher(self):
        self.save_config()
        if self.watcher and self.watcher.is_alive():
            self.log("Watcher is already running.")
            return

        self.watcher = Watcher(self.config.copy(), load_state(), self.event_queue)
        self.watcher.start()
        self.status_vars["watcher"].set("Watching")
        self.log("Started watching for the BenTools queue banner.")

    def stop_watcher(self):
        if self.watcher:
            self.watcher.stop()
            self.watcher = None
        self.status_vars["watcher"].set("Stopped")
        self.log("Stop requested.")

    def capture_preview(self):
        try:
            window_info = find_wow_window()
            if not window_info:
                self.log("Could not find a World of Warcraft window.")
                return
            _, frame_bgr, _ = capture_roi(window_info)
            score, rect = detect_beacon(frame_bgr)
            frame_rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)
            preview = Image.fromarray(frame_rgb)

            if rect:
                import PIL.ImageDraw

                draw = PIL.ImageDraw.Draw(preview)
                x, y, w, h = rect
                draw.rectangle((x, y, x + w, y + h), outline="#38bdf8", width=3)

            preview.thumbnail((420, 300))
            self.preview_image = ImageTk.PhotoImage(preview)
            self.preview_label.configure(image=self.preview_image)
            self.status_vars["score"].set(f"{score:.3f}")
            self.log(f"Captured preview. Detector score: {score:.3f}")
        except Exception as exc:
            self.log(f"Preview capture failed: {exc}")

    def launch_game_from_ui(self):
        self.save_config()
        try:
            launched = launch_game_target(self.config)
            self.log(f"Launched {launched}")
        except Exception as exc:
            messagebox.showerror(APP_TITLE, str(exc))

    def apply_startup_preferences(self):
        if self.config.get("startMinimized"):
            self.root.after(100, self.hide_to_tray if self.tray_ready else self.root.iconify)
        if self.config.get("startWatchingAutomatically"):
            self.root.after(300, self.start_watcher)

    def process_events(self):
        while True:
            try:
                kind, payload = self.event_queue.get_nowait()
            except queue.Empty:
                break

            if kind == "log":
                self.log(payload["message"])
            elif kind == "status":
                if "wow" in payload:
                    self.status_vars["wow"].set("Found" if payload["wow"] == "found" else "Not found")
                if payload.get("detector") == "match":
                    self.status_vars["watcher"].set("Signal locked")
                elif payload.get("detector") == "clear" and self.watcher:
                    self.status_vars["watcher"].set("Watching")
            elif kind == "score":
                self.status_vars["score"].set(f"{payload.get('score', 0.0):.3f}")
            elif kind == "notified":
                self.state = load_state()
                self.refresh_status_labels()

        self.root.after(150, self.process_events)

    def on_close(self):
        self.hide_to_tray()

    def exit_app(self):
        self.stop_watcher()
        if self.tray_icon:
            try:
                self.tray_icon.stop()
            except Exception:
                pass
        self.root.destroy()


def run_test(config):
    payload = {
        "content": config.get("mention", ""),
        "embeds": [
            {
                "title": "Queue Ringer Test",
                "description": "Your Discord webhook is configured correctly.",
                "color": 5763719,
                "footer": {"text": "BenTools Queue Ringer"},
                "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time())),
            }
        ],
    }
    send_webhook(config, payload, print)


def run_launch_wow(config):
    launched = launch_game_target(config)
    print(f"Launched {launched}")


def main():
    parser = argparse.ArgumentParser(description=APP_TITLE)
    parser.add_argument("--test", action="store_true", help="Send a Discord test notification and exit.")
    parser.add_argument("--launch-wow", action="store_true", help="Launch World of Warcraft or Battle.net and exit.")
    args = parser.parse_args()

    if DEPENDENCY_ERROR is not None:
        message = (
            "Queue Ringer is missing Python packages.\n\n"
            "Run Start Queue Ringer.bat and let it install requirements, or run:\n"
            "py -3 -m pip install -r requirements.txt\n\n"
            f"Original error:\n{DEPENDENCY_ERROR}"
        )
        if args.test or args.launch_wow:
            print(message)
        else:
            root = tk.Tk()
            root.withdraw()
            messagebox.showerror(APP_TITLE, message)
            root.destroy()
        return

    try:
        config = load_config()
    except Exception as exc:
        if args.test or args.launch_wow:
            print(exc)
        else:
            root = tk.Tk()
            root.withdraw()
            messagebox.showerror(APP_TITLE, str(exc))
            root.destroy()
        return

    if args.test:
        run_test(config)
        return
    if args.launch_wow:
        try:
            run_launch_wow(config)
        except Exception as exc:
            print(exc)
        return

    guard = SingleInstanceGuard(SINGLE_INSTANCE_MUTEX)
    if not guard.acquire():
        print("BenTools Queue Ringer is already running.")
        return

    try:
        hide_console_window()
        state = load_state()
        root = tk.Tk()
        QueueRingerApp(root, config, state)
        root.mainloop()
    except Exception as exc:
        root = tk.Tk()
        root.withdraw()
        messagebox.showerror(APP_TITLE, str(exc))
        root.destroy()
    finally:
        guard.release()


if __name__ == "__main__":
    main()
