# Sourced by install.sh; shared variables come from the entry point and temp.sh.
# shellcheck disable=SC2154
# Apply the repo TUIOS config at the path selected by the installed version.
tuios_source="$DOTFILES_ROOT/config/tuios/config.toml"
[[ -f "$tuios_source" && ! -L "$tuios_source" ]] || { echo "Missing repo TUIOS config: $tuios_source" >&2; exit 1; }
tuios_config="$(tuios config path)"
[[ "$tuios_config" == /*/config.toml ]] || { echo "Unexpected TUIOS config path: $tuios_config" >&2; exit 1; }
[[ ! -d "$tuios_config" || -L "$tuios_config" ]] || { echo "Expected a file at $tuios_config; leaving the directory untouched." >&2; exit 1; }
mkdir -p "$(dirname "$tuios_config")"
cp "$tuios_source" "$_dotfiles_download_dir/tuios-config.toml"
rm -f -- "$tuios_config"
mv "$_dotfiles_download_dir/tuios-config.toml" "$tuios_config"
echo "TUIOS config applied: $tuios_config"
