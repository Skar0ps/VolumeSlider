# Godot Volume Slider

[![Godot Version](https://img.shields.io/badge/Godot-4.x-blue?style=for-the-badge&logo=godot-engine)](https://godotengine.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

A simple and ready-to-use volume slider plugin for Godot 4. It provides `HVolumeSlider` and `VVolumeSlider` nodes that directly control the volume of any audio bus.

![Volume Slider Preview](icon.png)

## Features

- **Dynamic Bus Selection**: Select the audio bus from a dropdown list in the Inspector, which is automatically populated with your project's actual audio buses.
- **Horizontal & Vertical Slider** :
  - ![horizontal volume slider icon](addons/volume_slider/icons/HVolumeSlider.svg) `HVolumeSlider`
  - ![vertical volume slider icon](addons/volume_slider/icons/VVolumeSlider.svg) `VVolumeSlider`
- **Automatic dB Conversion**: Automatically converts the slider's linear value (by default 0-100) to the logarithmic dB scale used by Godot's `AudioServer`.
  - The conversion is based on the slider's range. The slider's `max_value` is mapped to full volume (0 dB), while its `min_value` is mapped to silence (-60db).
- **Auto-Mute**: Automatically mutes the bus when the volume is set to its minimum value.
- **Volume Signal**: Emits a `volume_changed(volume_db)` signal whenever the volume is adjusted.

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

1. After enabling the plugin, two new nodes will be available : `HVolumeSlider` and `VVolumeSlider`.
2. Add one of these nodes to your scene.
3. In the Inspector, find the **Bus Name** property.
4. Select the desired audio bus from the dropdown list (e.g., "Master", "Music", "SFX").
5. That's it! The slider will now control the volume of the selected bus when the game is running.

## License

This plugin is released under the MIT License. See the [LICENSE](addons/volume_slider/LICENSE) file for more details.
