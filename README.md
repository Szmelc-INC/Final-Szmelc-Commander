# Final-Szmelc-Commander
ostateczny szmelc commander szmelc commanderów!!!

---

# === Setup ===
> ## Online installer
> ```bash
> sh -c "$(curl -fsSL https://raw.githubusercontent.com/Szmelc-INC/Final-Szmelc-Commander/refs/heads/main/init.sh)"
> ```
> 
> ## Add `szmelc` Alias to shell
> ```bash
> echo 'alias szmelc='\''sh -c "$(curl -fsSL https://raw.githubusercontent.com/Szmelc-INC/Final-Szmelc-Commander/refs/heads/main/init.sh)"'\''' >> "$HOME/.${SHELL##*/}rc" && echo "✓ Alias added. Restart your terminal or run: source \$HOME/.${SHELL##*/}rc"
> ```

---

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
```sh
export SC_GH_RAW="https://raw.githubusercontent.com/Szmelc-INC/Final-Szmelc-Commander/refs/heads/main"
```
Then you can to run installer in scripts with less code
```sh
sh -c "$(curl -fsSL $SC_GH_RAW/init.sh)"
```
