"""Exercise the real Lua validation code with stubbed plugin-manager state."""
from pathlib import Path
import shutil
import subprocess
import tempfile

lua = shutil.which('lua')
if not lua:
    print('SKIP: Lua validation tests require a lua interpreter; nothing installed.')
    raise SystemExit(0)
script = Path(__file__).resolve().parents[1] / 'scripts/lib/sync_lazyvim.lua'
for scenario, succeeds in [('ok', True), ('task-error', False), ('missing', False), ('startup', False), ('empty', False), ('sync-error', False)]:
    harness = '''
local scenario = arg[1]
local result = nil
vim = {
  v = { errmsg = scenario == 'startup' and 'bad init' or '' },
  api = { nvim_err_writeln = function(_) end },
  cmd = function(command) result = command end,
}
package.preload['lazy'] = function()
  return { sync = function(opts)
    assert(opts.wait == true and opts.show == false)
    if scenario == 'sync-error' then error('sync failed') end
  end }
end
package.preload['lazy.core.config'] = function()
  local plugins = { example = { url = 'https://example.invalid/plugin', _ = {
    installed = scenario ~= 'missing',
    tasks = {{ has_errors = function() return scenario == 'task-error' end }},
  }}}
  return { plugins = scenario == 'empty' and {} or plugins }
end
dofile(arg[2])
assert(result == (arg[3] == 'true' and 'qa!' or 'cquit 1'), tostring(result))
'''
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / 'harness.lua'
        path.write_text(harness)
        subprocess.run([lua, str(path), scenario, str(script), str(succeeds).lower()], check=True)
print('PASS: Lua sync validator handles success, task errors, missing plugins, startup errors, empty config and sync exceptions. Neovim/plugins were not launched.')
