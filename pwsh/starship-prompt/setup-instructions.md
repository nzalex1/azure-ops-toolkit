# Starship Prompt: Windows PowerShell Installation & Configuration Guide

A comprehensive guide to installing and configuring the ultra-fast, minimal, and rock-solid **Starship** prompt engine on Windows PowerShell without relying on complex Nerd Font installations.

---

## 1. Installation

Open **Windows PowerShell** as an Administrator and execute the following command using the Windows Package Manager (`winget`):

```powershell
winget install Starship.Starship
```
*Note: If prompted to accept source agreements, press `Y` and hit Enter.*

---

## 2. Configuration Setup

Starship looks for its configuration file at `$HOME\.config\starship.toml`. Run the following script in PowerShell to automatically create the folder structure and open the file in Notepad:

```powershell
# Create the config directory if it does not exist
if (!(Test-Path "$HOME\.config")) { 
    New-Item -ItemType Directory -Path "$HOME\.config" -Force 
}

# Open the configuration file in Notepad
notepad "$HOME\.config\starship.toml"
```
*If Notepad asks if you want to create a new file, select **Yes**.*

---

## 3. Minimalist Configuration File (`starship.toml`)

Paste the following configuration blocks directly into your open `starship.toml` file. This setup overrides default Nerd Font icons with **clean, universally compatible text labels** to ensure zero layout errors or missing icon symbols (``):

```toml
# Main layout format string
format = "$all"

[git_branch]
# Replaces the broken glyph icon with a clean text prefix
symbol = "git:"
style = "bold purple"
format = "on [$symbol$branch]($style) "

[git_status]
# High-contrast indicators compatible with all default fonts
conflicted = "="
ahead = "⇡"
behind = "⇣"
diverged = "⇕"
untracked = "?"
stashed = "$"
modified = "!"
staged = "+"
renamed = "»"
deleted = "✘"
```

Save the file (`Ctrl + S`) and close Notepad.

---

## 4. Customizing Prompt Colors and Layouts

You can fine-tune colors for any module inside your `starship.toml`. Colors can be specified using simple color names (`red`, `green`, `blue`, `yellow`, `purple`, `cyan`, `white`, `black`) or hex codes (e.g., `#ff5555`).

### Changing Directory and Cursor Colors
To change the appearance of your current directory path and the typing cursor (`>`), append these blocks to your configuration file:

```toml
[directory]
style = "bold cyan"        # Changes the directory path text color
read_only = " [RO]"        # Pure text fallback for read-only folders

[character]
success_symbol = "[>](bold green)" # Color of cursor when previous command succeeds
error_symbol = "[>](bold red)"     # Color of cursor when a command fails
```

### Prompt Color Quick-Reference Examples
Modify the `style` values under your blocks to quickly swap themes:
* **Production Feel**: Set directory to `"bold red"` and git_branch to `"bold yellow"`.
* **Clean DevOps Vibe**: Set directory to `"bold blue"` and git_branch to `"bold green"`.

---

## 5. Activation in PowerShell Profile

To ensure Starship initializes automatically every time you open a new terminal window, add it directly to your PowerShell Profile script:

1. Open your active profile path in Notepad:
   ```powershell
   notepad $PROFILE
   ```
2. Remove any old prompt engine strings (such as `oh-my-posh`) to prevent command execution errors.
3. Append this exact initialization code string to the bottom of the file:
   ```powershell
   Invoke-Expression (&starship init powershell)
   ```
4. Save the file and restart your **Windows Terminal** instance.

---

## 6. Maintenance Commands

### Updating Starship
Keep the compilation binary updated to the latest stable release via winget:
```powershell
winget upgrade Starship.Starship
```

### Quick Re-editing
If you ever want to fine-tune your module colors or prompt behavior down the road, use this quick alias shortcut path:
```powershell
notepad \$env:USERPROFILE\.config\starship.toml
```
