#!/usr/bin/env python3
"""
Генерирует WAV-файлы для IVR меню на русском языке через gTTS.
Запускается один раз при старте контейнера.
"""

import os
import sys
import subprocess

SOUNDS_DIR = "/var/lib/asterisk/sounds/ivr"

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

def generate(key, text):
    mp3_path = f"/tmp/ivr_{key}.mp3"
    wav_path = f"{SOUNDS_DIR}/{key}.wav"

    if os.path.exists(wav_path):
        print(f"  [SKIP] {key}.wav already exists")
        return

    try:
        from gtts import gTTS
        tts = gTTS(text=text, lang="ru", slow=False)
        tts.save(mp3_path)

        # Convert MP3 → WAV 8000Hz mono (Asterisk ulaw-compatible)
        result = subprocess.run([
            "sox", mp3_path,
            "-r", "8000",
            "-c", "1",
            "-e", "signed-integer",
            "-b", "16",
            wav_path
        ], capture_output=True, text=True)

        if result.returncode != 0:
            print(f"  [ERROR] sox failed for {key}: {result.stderr}")
            sys.exit(1)

        os.remove(mp3_path)
        print(f"  [OK] Generated: {key}.wav")

    except Exception as e:
        print(f"  [ERROR] {key}: {e}")
        sys.exit(1)


def main():
    os.makedirs(SOUNDS_DIR, exist_ok=True)
    print(f"Generating IVR sounds in {SOUNDS_DIR} ...")
    for key, text in PHRASES.items():
        generate(key, text)
    print("All sounds ready.")


if __name__ == "__main__":
    main()