# Mine Rush

Roblox place `MineRush.rbxlx` — open it in Roblox Studio.

- `src/` — editable script sources (Client, Config, GameServer, WorldBuilder, ModelLibrary).
- `place/MineRush.base.rbxlx` — the original place the sources are injected into.
- `python3 tools/build_place.py` — rebuilds `MineRush.rbxlx` from `src/`.
- `tests/run_smoke.sh` — builds every tool, egg and pet against Roblox API stubs (needs the `luau` CLI).

## Using your own models

`ModelLibrary` generates detailed tools, eggs and pets. To replace any of them with a model
from the Creator Store, insert it in Studio and put it into `ReplicatedStorage.Assets`:

| Folder | Model name | Requirements |
|---|---|---|
| `Assets/Tools` | tool name, e.g. `Ruby Pickaxe` | a `Tool` with a `Handle` part |
| `Assets/Eggs` | egg name, e.g. `Magma Egg` | a `Model` (PrimaryPart = shell) |
| `Assets/Pets` | pet name, e.g. `Phoenix` | a `Model` (PrimaryPart = body, facing -Z) |

Models must be in the place itself; Roblox does not let a game load other creators' models at runtime.
