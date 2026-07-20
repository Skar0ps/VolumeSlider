# Godot Volume Slider

[![Godot Version](https://img.shields.io/badge/Godot-4.x-blue?style=for-the-badge&logo=godot-engine)](https://godotengine.org/)
[![GDScript](https://img.shields.io/badge/GDScript-%2374267B.svg?style=for-the-badge&logo=godotengine&logoColor=white)](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/index.html)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)
[![AssetLib](https://img.shields.io/badge/Asset%20Library-Volume%20Slider-478cbf?style=for-the-badge&logo=godotengine&logoColor=white)](https://godotengine.org/asset-library/asset)

A simple and ready-to-use volume slider plugin for Godot 4. It provides `HVolumeSlider` and `VVolumeSlider` nodes that directly control the volume of any audio bus, with optional persistence, mute buttons, labels, and accessibility support.

![Volume Slider Preview](icon.png)

## Features

- **Dynamic Bus Selection**: Select the audio bus from a dropdown list in the Inspector, automatically populated with your project's actual audio buses.
- **Horizontal & Vertical Slider**:
  - ![horizontal volume slider icon](addons/volume_slider/icons/HVolumeSlider.svg) `HVolumeSlider`
  - ![vertical volume slider icon](addons/volume_slider/icons/VVolumeSlider.svg) `VVolumeSlider`
- **Automatic dB Conversion**: Converts the slider's linear value (0-100 by default) to the logarithmic dB scale used by Godot's `AudioServer`. `max_value` maps to full volume (0 dB), `min_value` maps to silence.
- **Auto-Mute**: Automatically mutes the bus when the volume is set to its minimum value, with dedicated `muted`/`unmuted` signals and custom grabber icon overrides for the muted state.
- **One-Click Mute Button**: Generate a linked `CheckBox` mute button directly from the Inspector. It's automatically wrapped in a matching `VBoxContainer`/`HBoxContainer` when needed, preserves the original layout (anchors, offsets, size flags), and is fully undo/redo-friendly in the editor.
- **Volume Persistence**: Optionally save/restore each bus's volume to a `ConfigFile`. A lightweight autoload is only added to the project when persisted volumes actually exist, so the correct volume is restored at game startup even before any slider is instanced.
- **Label Display**: Optionally bind a `Label` to show the live volume percentage, with optional rounding and editor preview.
- **Accessibility**: Built-in tooltip with configurable bus name/decibel display, plus auto-filled screen-reader accessibility name and description.
- **Volume Signal**: Emits `volume_changed(volume_db)` whenever the volume changes.

## Installation

### From Godot Asset Library (Recommended)

1. Open the **AssetLib** tab in the Godot editor.
2. Search for "Volume Slider".
3. Click **Download**, and then **Install**.
4. Enable the plugin in **Project -> Project Settings -> Plugins**.

### Manual Installation

1. Download the latest release from the [GitHub repository's releases page](https://github.com/Skar0ps/VolumeSlider/releases).
2. Extract the `addons` folder from the ZIP file.
3. Place the `addons` folder in your project's root directory.
4. Enable the plugin in **Project -> Project Settings -> Plugins**.

## How to Use

1. After enabling the plugin, two new nodes are available: `HVolumeSlider` and `VVolumeSlider`.
    > [!NOTE]
    > An Autoload will also be added, named `VolumeSliderBootstrap`.
    > It is used for loading and applying the persisted volumes in the ConfigFile on startup.
    >
    > It will free itself automatically after applying the persisted volumes or free itself immediatly if there are no persisted volumes.
2. Add one of these nodes to your scene.
3. In the Inspector, find the **Bus Name** property and select the desired audio bus (e.g., "Master", "Music", "SFX").
4. That's it! The slider now controls the volume of the selected bus at runtime.

### Optional features

- **Mute button**: click **Create a mute button** in the Inspector to generate a linked `CheckBox`, or assign your own `Button` (with `toggle_mode` enabled) as the `mute_button`.
- **Save Volume**: enable the group and set a `ConfigFile` path to persist the volume across sessions.
- **Label Display**: enable the group and assign a `Label` node to show the current volume.
- **Tooltip Display**: enable the group under **Accessibility** to show a hover tooltip with the volume, bus name, and decibel value.

## License

This plugin is released under the MIT License. See the [LICENSE](addons/volume_slider/LICENSE) file for more details.
