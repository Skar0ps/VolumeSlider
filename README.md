# Godot Volume Slider

[![Godot Version](https://img.shields.io/badge/Godot-4.x-6393ff.svg?style=flat-square&logo=godotengine&logoColor=white)](https://godotengine.org/)
[![GDScript](https://img.shields.io/badge/GDScript-6393ff.svg?style=flat-square&logo=godotengine&logoColor=242232)](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/index.html)
[![License: MIT](https://img.shields.io/badge/License-MIT-ffcb77.svg?style=flat-square)](https://opensource.org/licenses/MIT)
[![AssetLib](https://img.shields.io/badge/Asset%20Store-Volume%20Slider-6aff7c.svg?style=flat-square&logo=godotengine&logoColor=white)](https://store.godotengine.org/asset/skar0ps/volume-slider/)

A simple and ready-to-use volume slider plugin for Godot 4. It provides `HVolumeSlider` and `VVolumeSlider` nodes that directly control the volume of any audio bus, with mute buttons, labels, tooltips, and accessibility support built in — no scripting required.

![Volume Slider Preview](icon.png)

## Features

- **Horizontal & Vertical Slider**:
  - ![horizontal volume slider icon](addons/volume_slider/icons/HVolumeSlider.svg) `HVolumeSlider`
  - ![vertical volume slider icon](addons/volume_slider/icons/VVolumeSlider.svg) `VVolumeSlider`
- **Dynamic Bus Selection**: Select the audio bus from a dropdown list in the Inspector, automatically populated with your project's actual audio buses and kept in sync if buses are renamed or the layout changes.

  ![Inspector screenshot with the bus_name property clicked and the dropdown menu shown with all the available audio buses](docs/dynamic_bus_enum.jpg)
- **Automatic dB Conversion**: Converts the slider's linear value (0-100 by default) to the logarithmic dB scale used by Godot's `AudioServer`. A value of 100 always corresponds to 0 dB (unity gain, no change), and a value of 0 corresponds to silence.

  ![Inspector screenshot with the min_value, max_value, and value properties shown with a decibel equivalent as a suffix beside them. The user is manipulating the values to show the dB suffix changing dynamically to show the actual dB value.](docs/dynamic_db_suffix.webp)
- **Optional Gain Boost**: `min_value` is locked to 0 (always corresponding to silence) and always shown read-only with its dB suffix, while `max_value` can optionally be raised up to 200 to allow boosting the bus volume above unity gain for players who want extra headroom.
- **Auto-Mute**: Automatically mutes the bus when the volume is set to its minimum value, with dedicated `muted`/`unmuted` signals and custom grabber icon overrides for the muted state.

  ![Animation of a scene with a horizontal volume slider going from the maximum value to the minimum value. When the slider is at the minimum value, the slider is shown muted by having the grabber icon show a red cross over it.](docs/dynamic_mute.webp)
- **One-Click Mute Button**: Generate a linked `CheckBox` mute button directly from the Inspector. It's automatically wrapped in a matching `VBoxContainer`/`HBoxContainer` when needed, preserves the original layout (anchors, offsets, size flags), and is fully undo/redo-friendly in the editor.

  ![Video of the editor shown with a volume slider selected and the user clicking on the tool button "Create a mute button" and a linked `CheckBox` is generated in the tree with the volume slider reparented to an `HBoxContainer` automatically with the mute button being the first child and the volume slider being the second.](docs/dynamic_mute_button_creation.webp)
- **Label Display**: Generate or bind a `Label` to show the live volume percentage, with optional rounding and editor preview. Like the mute button, it's also automatically wrapped in a matching `VBoxContainer`/`HBoxContainer` when needed, preserves the original layout (anchors, offsets, size flags), and is fully undo/redo-friendly in the editor.

  ![Video of the editor shown with a volume slider selected and the user clicking on the tool button "Create a volume label" and a linked `Label` is generated in the tree with the volume slider reparented to an `HBoxContainer` automatically with the volume slider being the first child and the label being the second.](docs/dynamic_display_label_creation.webp)
- **Dynamic Tooltip**: Built-in tooltip with configurable bus name/decibel display, plus auto-filled screen-reader accessibility name and description.

  ![Inspector video with the tooltip enabled and the user changing the value of the volume slider, showcasing the tooltip preview in the inspector updating based on the value with the bus name, percentage, and decibel value in parenthesis.](docs/dynamic_tooltip_preview.webp)
  
  ![Video of a scene with a horizontal volume slider being hovered while muted, with a tooltip appearing with the bus name, percentage, and decibel value in parenthesis. The user slides the slider to another value and waits to show the updated tooltip, repeating this operation two times before setting the slider value to its minimum value.](docs/dynamic_tooltip_scene_example.webp)
- **Volume Signals**: Emits `volume_changed(volume_db)` whenever the volume changes, `muted` when the slider triggers a bus to be muted (reaching the minimum value), and `unmuted` when the slider triggers a bus to be unmuted (sliding the slider to any non-minimum value).
- **Gain boost**: raise `max_value` above 100 (up to 200) to allow the slider to go past unity gain and amplify the bus volume.
- **Custom Theme Overrides**: The grabber icon can be customized by assigning a `Texture2D` to the `grabber_muted` and `grabber_unmuted` properties in the Theme Overrides or in your project's `Theme` resource. The plugin provides default icons for both the muted and unmuted states in the [Theme resource](addons/volume_slider/icons/volume_slider_theme.tres).
![Editor screenshot showing the Theme Overrides inspector dropdown with the Icons subgroup having the grabber_muted and grabber_unmuted properties with default textures](docs/theme_overrides.jpg)
  
  You can also import the `grabber_muted` and `grabber_unmuted` icons theme properties for the classes `VVolumeSlider` and `HVolumeSlider` into your project's `Theme`.

  ![Editor screenshot showing the popup window on the "Import Items" tab for the Theme resource with the grabber_muted and grabber_unmuted properties checked from the volume_slider_theme.tres file](docs/import_icons_from_theme.jpg)

## Installation

### From Godot Asset Store (Recommended)

1. Open the **Asset Store** tab in the Godot editor.
2. Search for "Volume Slider".
3. Click **Download**, and then **Install**.
4. Enable the plugin in **Project -> Project Settings -> Plugins**.

### Manual Installation

1. Download the latest `volume_slider.zip` from the [GitHub repository's releases page](https://github.com/Skar0ps/VolumeSlider/releases); this archive contains only the `addons` folder.
2. Extract the contents of the ZIP file into your project's root folder.
3. Enable the plugin in **Project -> Project Settings -> Plugins**.

## How to Use

1. After enabling the plugin, two new nodes are available: `HVolumeSlider` and `VVolumeSlider`.
2. Add one of these nodes to your scene.
3. In the Inspector, find the **Bus Name** property and select the desired audio bus (e.g., "Master", "Music", "SFX").
4. That's it! The slider now controls the volume of the selected bus at runtime.

## License

This plugin is released under the MIT License. See the [LICENSE](addons/volume_slider/LICENSE) file for more details.
