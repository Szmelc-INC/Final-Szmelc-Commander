> # Final-Szmelc-Commander
> ### Ostateczny szmelc commander szmelc commanderów!!!

---

> # Setup
> ## Online installer
> Szmelc.com (short-form)
> ```sh
> sh -c "$(curl -fsSL https://szmelc.com/commander/)"
> ```
> OG GitHub (long-form)
> ```bash
> sh -c "$(curl -fsSL https://raw.githubusercontent.com/Szmelc-INC/Final-Szmelc-Commander/refs/heads/main/init.sh)"
> ```
> ## Add `szmelc` Alias to shell
> ```bash
> echo 'alias szmelc='\''sh -c "$(curl -fsSL https://raw.githubusercontent.com/Szmelc-INC/Final-Szmelc-Commander/refs/heads/main/init.sh)"'\''' >> "$HOME/.${SHELL##*/}rc" && echo "✓ Alias added. Restart your terminal or run: source \$HOME/.${SHELL##*/}rc"
> ```

---

> # Features
> ### Automatic Host details script
> Used in `init.sh`, to identify all points of interests on host. Raport saved as `/tmp/.host-info`
<img width="534" height="637" alt="image" src="https://github.com/user-attachments/assets/0e9e6519-bd00-4cf9-a569-4917e705d821" />


---

> # Other fun things
> ### RAW
> ### --- URL's for raw scripts ---
> ```bash
> # Main dir as ($SZMELC_COMMANDER_GH_RAW)
> https://raw.githubusercontent.com/Szmelc-INC/Final-Szmelc-Commander/refs/heads/main/
>
> # Init script ($SZMELC_COMMANDER_GH_RAW/init.sh)
> https://raw.githubusercontent.com/Szmelc-INC/Final-Szmelc-Commander/refs/heads/main/init.sh
> ```

> ### Exports
> Main GitHub RAW URL `SC_GH_RAW`
> ```sh
> export SC_GH_RAW="https://raw.githubusercontent.com/Szmelc-INC/Final-Szmelc-Commander/refs/heads/main"
> ```
> Then you can to run installer in scripts with less code
> ```sh
> sh -c "$(curl -fsSL $SC_GH_RAW/init.sh)"
> ```

> ### Base64 runner
> [Online encoder/decoder](https://www.base64encode.org/)
> ```sh
> sh -c 'export B64="<Base64_String_Here>"; sh -c "$(echo $B64 | base64 -d)"'
> ```

> Export
```sh
export B64="<Base64_String_Here>"
```
> Run from `$B64`
```sh
sh -c "$(echo $B64 | base64 -d)"
```
