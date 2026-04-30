#!/usr/bin/env python3
"""
Генерирует WAV-файлы для IVR меню на русском языке через gTTS.
Запускается один раз при старте контейнера.
"""

import os
import sys
import subprocess
from gtts import gTTS

SOUNDS_DIR = "/usr/share/asterisk/sounds/ivr"

PHRASES = {
    "main_menu": (
        "Добро пожаловать в меню. "
        "Наберите 1, чтобы улыбнуться. "
        "Наберите 2, чтобы усложнить задание. "
        "Наберите 3, чтобы записать голосовое сообщение."
    ),
    "you_smiled":       "Вы улыбнулись.",
    "press_any_digit":  "Нажмите любую цифру от 0 до 9.",
    "you_pressed":      "Вы нажали",
    "please_record": (
        "Прошу продиктовать ваше сообщение после сигнала и нажать решётку."
    ),
    "your_message_is":  "Ваше сообщение:",
    "invalid_option":   "Неверный выбор. Пожалуйста, попробуйте снова.",
}

# Полные фразы "Вы нажали X цифру" для каждой цифры 0–9.
# Файлы: you_pressed_0.ulaw … you_pressed_9.ulaw
# Можно использовать напрямую в extensions.conf:
#   exten => _X,n,Playback(ivr/you_pressed_${EXTEN})
DIGIT_NAMES = {
    0: "ноль",
    1: "один",
    2: "два",
    3: "три",
    4: "четыре",
    5: "пять",
    6: "шесть",
    7: "семь",
    8: "восемь",
    9: "девять",
}

DIGIT_PHRASES = {
    f"you_pressed_{digit}": f"Вы нажали цифру {name}."
    for digit, name in DIGIT_NAMES.items()
}


def generate(key, text):
    mp3_path = f"/tmp/ivr_{key}.mp3"
    wav_path = f"{SOUNDS_DIR}/{key}.wav"
    ulaw_path = f"{SOUNDS_DIR}/{key}.ulaw"

    if os.path.exists(ulaw_path):
        print(f"[SKIP] {key}")
        return

    tts = gTTS(text=text, lang="ru", slow=False)
    tts.save(mp3_path)

    # 1. WAV (intermediate)
    subprocess.run([
        "sox", mp3_path,
        "-r", "8000",
        "-c", "1",
        wav_path
    ], check=True)

    # 2. ULAW (IMPORTANT FOR ASTERISK)
    subprocess.run([
        "sox", wav_path,
        "-t", "ul",  # mu-law format
        "-r", "8000",
        "-c", "1",
        ulaw_path
    ], check=True)

    os.remove(mp3_path)

    print(f"[OK] {key}.wav + .ulaw")


def main():
    os.makedirs(SOUNDS_DIR, exist_ok=True)
    print(f"Generating IVR sounds in {SOUNDS_DIR} ...")

    all_phrases = {**PHRASES, **DIGIT_PHRASES}
    for key, text in all_phrases.items():
        generate(key, text)

    print("All sounds ready.")


if __name__ == "__main__":
    main()