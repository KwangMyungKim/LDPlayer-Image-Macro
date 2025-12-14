# LDPlayer Image Macro

**LDPlayer Image Macro** is a lightweight, powerful automation tool built with **AutoHotkey v2**. It is designed specifically for the LDPlayer Android emulator (and compatible with other emulators with "Android" in the title) to automate repetitive tasks using image recognition and coordinate clicking.

Unlike simple clickers, this tool utilizes **ControlClick**, allowing it to operate without stealing your mouse cursor focus, letting you multitask while the macro runs.

## ✨ Key Features

*   **Background Automation (Non-Intrusive)**
    *   Uses `ControlClick` to send input directly to the emulator window.
    *   You can use your mouse for other tasks while the macro is running.
    *   *Note: The emulator window must be visible on the screen (not minimized) for image recognition to work.*

*   **Dual Operation Modes**
    *   **Image Search:** Finds a specific image on the screen and clicks its center. Supports customizable color tolerance (0-255).
    *   **Coordinate Click:** Clicks a specific X, Y coordinate relative to the emulator window.

*   **Smart Script Editor**
    *   **GUI Interface:** Easily Add, Modify, Delete, and Reorder script steps via a clean interface.
    *   **Selective Execution:** Use checkboxes to toggle specific steps on or off without deleting them.
    *   **Coordinate Picker:** Built-in tool to easily grab X, Y coordinates. Just press **F1** over the target area to auto-fill the coordinates.

*   **Robust & User-Friendly**
    *   **Multi-Language Support:** Fully localized in **English** and **Korean**. Switch languages instantly via the menu.
    *   **Auto-Save:** Your script and settings are automatically saved (`macro_data.txt`) and loaded upon startup.
    *   **DPI Aware:** Automatically adjusts for high-resolution displays to ensure click accuracy.
    *   **Window Selection:** Detects running LDPlayer instances and lets you select the target window from a dropdown list.

## 🚀 Getting Started

### Prerequisites
*   **AutoHotkey v2**: You must have AutoHotkey v2 installed. [Download here](https://www.autohotkey.com/).

### Installation
1.  Clone this repository or download the source code.
2.  Ensure the `Images` folder exists in the same directory. Place your target images (`.png`, `.bmp`, etc.) inside this folder.
3.  Run `LDPlayerImageMacro.ahk`.

## 📖 How to Use

1.  **Select Window:** Open the app and select your LDPlayer instance from the dropdown menu. Click "Refresh" if it doesn't appear.
2.  **Edit Script:** Go to the **Script Editor** tab.
    *   Click **Add** to create a new step.
    *   Choose **Image** to search for a picture (use the "Browse" button).
    *   Choose **Coordinate** to click a specific spot. Use the **"Pick (F1)"** button to easily capture the coordinates from the emulator.
3.  **Run:** Go to the **Macro** tab and press **Start (F1)**.
4.  **Stop:** Press **Stop (F2)** to halt the execution.

## 📂 File Structure

*   `LDPlayerImageMacro.ahk`: The main source code.
*   `locales.ini`: Language data file (English/Korean).
*   `macro_data.txt`: Stores your saved macro steps (auto-generated).
*   `settings.ini`: Stores application settings like language preference (auto-generated).
*   `Images/`: Directory to store your image assets.

## ⚠️ Notes
*   **Image Recognition:** Ensure your emulator window is not covered by other windows when the macro is "Searching" for an image. While clicking works in the background, standard `ImageSearch` requires pixel visibility.
*   **Administrator Privileges:** If LDPlayer is running as Admin, you might need to run this script as Administrator as well.

## 📝 License
This project is open-source. Feel free to modify and distribute.
