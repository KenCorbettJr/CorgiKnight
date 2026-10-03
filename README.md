# CorgiKnight

A cute 3D corgi adventure made with Godot 4.

## How to play it

1. Download **Godot 4** (the standard version, not .NET) from https://godotengine.org/download.
2. Open Godot, click **Import**, and pick the `project.godot` file in this folder.
3. Press **F5** (or the ▶ Play button at the top right).

The first time you open it, Godot will spend a few seconds importing files. That's normal.

## Controls

The game starts on the **title screen**: click **Start** (or press Enter).

There are two camera styles. Press **C** to switch:

- **Behind the corgi** (default): the camera stays behind the corgi's head. W walks forward, S backs up, A/D or the mouse turn.
- **Free look**: move the mouse to look anywhere, and WASD moves the way the camera faces.


| Action | Keyboard & mouse | Controller |
|---|---|---|
| Move | W / S forward and back, A / D turn (arrow keys too) | Left stick |
| Turn / look around | Mouse | Right stick |
| Switch camera | C | Click right stick |
| Jump | Space | A |
| Run | Shift | Left bumper |
| Swing sword / axe | Left click / J | X |
| Switch weapon | Q | Right bumper |
| Talk | E | Y |
| Free the mouse | Esc (click to grab it again) | — |

If you run out of hearts, you'll see **You died!** and then wake up back in your bed with full hearts. Every 3rd bad guy you defeat drops a floating **heart** that refills one heart.

**Story:** you wake up in bed in your little house. Talk to **Mom** (walk up to her and press **E**) and she'll give you a **Wooden Sword**. Then head outside, bonk slimes, and collect **5 Slime Jelly** (each bonked slime drops one, and slimes come back after a while). Bring the jelly home and Mom gives you her old **Axe**: chop down trees (a few swings each; they grow back later) and collect **5 Wood** for the stove. Bring it home and Mom gives you a **Red Cape** that flutters when you run and gives you an extra heart! The purple King Slime waits on top of the stone lookout (it hits twice as hard!).

**The village:** just south of home is Corgi Village, with Old Barnaby, little Pip, Maple and Clover to chat with. At **Biscuit's Shop** you can sell extra Slime Jelly (3 coins each) and Wood (2 coins each) and buy gear: Leather Cap, Wooden Shield, Speedy Boots, Iron Helmet and Iron Sword. The shop never buys the jelly or wood Mom's quest still needs.

**The well cave and the first boss:** once you've finished Mom's quests and own all four pieces of armor (Leather Cap, Wooden Shield, Speedy Boots, Iron Helmet), the village well starts to glow purple and a rope appears. Climb down (press **E** at the well) into the **Well Cave**: fight the cave slimes, follow the glowing crystals through the tunnel, and find the **Slime Stone** on its pedestal. Taking it pulls you back up to the village... where the evil **Corgiwizard** has been waiting for someone to fetch it! He appears over the village well. The sky goes dark, everyone runs and hides, and he summons the **King Slime**! It hops after you and every third hop leaps high and slams down with a shockwave, so **jump** to dodge it. At half health it turns red, gets faster and calls in two helper slimes. Beat it to break the curse, bring the sun back, and unlock **Captain Salty's** boat at the north dock.

**Island 2, the Whispering Woods:** talk to Captain Salty to sail to a thick forest island (and back home whenever you like). Ranger Rowan runs the camp by the dock, and **Juniper's Trading Post** sells tougher gear: Chainmail, Knight Shield, Forest Boots, Steel Helmet and Steel Sword. The woods are full of **mini cyclopses**: they raise their club high and SMASH (2 hearts!), so watch for the wind-up and dodge, or bonk them first to interrupt. Each one drops a **Cyclops Tooth** (sells for 10 coins) and **5 coins**. Follow the path north to the old stone shrine and take the **Golden Acorn**... and the Corgiwizard comes back, furious that you keep finding his hidden treasures! He summons the **Giant Cyclops**: stay out of the way of its club smash (hit it while it pulls the club back up), and **jump** its stomp shockwave. At half health it gets furious and calls in two mini cyclopses. (More islands coming soon!)

## What's in here

```
scenes/
  title.tscn        The title screen (the game starts here)
  main.tscn         The island: sky, sun, ground, water, the house, the lookout, slimes
  house.tscn        The corgi's cottage: bed, table, lamp, and Mom
  dock.tscn         The north dock, Captain Salty and his boat
  cave.tscn         The Well Cave (under the island) with the Slime Stone
  forest_island.tscn  Island 2: the Whispering Woods (camp, shop, shrine, cyclopses)
  forest_shop.tscn  Juniper's Trading Post
  cyclops.tscn      A mini cyclops enemy
  boss_cyclops.tscn The second boss
  heart_pickup.tscn A heart that refills health
  king_slime_boss.tscn  The first boss
  cottage.tscn      A village cottage (pick wall and roof colors in the Inspector)
  shop_stall.tscn   Biscuit's Shop: what it sells and the prices are on the Biscuit node
  characters/       The corgi body (shared by everyone), Mom, villager.tscn, and the Corgiwizard
  jelly_pickup.tscn Slime Jelly that slimes drop
  wood_pickup.tscn  Wood that chopped trees drop
  player.tscn       The corgi knight (made from simple shapes for now) + camera
  equipment/        Things the corgi can hold or wear (Wooden Sword, Axe, Red Cape, plus a spare sword)
  slime.tscn        A slime enemy
  tree.tscn         A puffy cartoon tree (chop it with the axe!)
  rock.tscn         A rock
  stone_block.tscn  A stone block (change its Size in the Inspector)
  hud.tscn          Hearts, quest tracker, dialogue box, pop-up messages
scripts/            The code for each of the above (lots of comments!)
                    boss_event.gd runs the whole Corgiwizard / King Slime scene
                    game_state.gd remembers the story progress and what you've collected
materials/          Toon-shaded colors + the cartoon outline
```

## Fun things to try together

- **Tweak the corgi:** open `scenes/player.tscn`, click the Player node, and change `Jump Velocity`, `Sprint Speed` or `Max Health` in the Inspector on the right.
- **Add more slimes:** open `scenes/main.tscn`, then drag `slime.tscn` from the FileSystem panel into the 3D view. Change its `Body Color`!
- **Build more of the world:** drag in more `stone_block.tscn` blocks and set their Size to make towers, walls and ruins.
- **New island layout:** click the Main node and change `World Seed` to move the trees and rocks around.
- **Recolor everything:** double-click a file in `materials/` to change its color.
- **Change what Mom says:** open `scripts/mom.gd`. All her lines are in quotes and easy to edit.
- **Make a new villager:** open `scenes/main.tscn`, drag `characters/villager.tscn` in, and set their Name, Fur Color, Size, Accessory and Lines in the Inspector. Put a `|` in a line to split it into two speech bubbles.
- **Hearts more often:** open `scripts/game_state.gd` and change `hearts_every := 3` to a smaller number.
- **Tune the cyclopses:** open `scenes/cyclops.tscn` (or click one in `forest_island.tscn`) and change Club Damage, Wind-up Seconds or Max Health.
- **Tune the boss:** open `scenes/king_slime_boss.tscn` and change Max Health, Hop Speed, Slam Every or Shockwave Radius.
- **Change the shop:** open `scenes/shop_stall.tscn`, click Biscuit, and edit Stock and Prices.
- **Make the quest harder:** open `scripts/game_state.gd` and change `jelly_goal := 5` or `wood_goal := 5` to bigger numbers.

## Equipment

The corgi has attachment points for gear: **head**, **chest**, **back**, **shield** (left paw),
**weapon** (right paw) and **feet** (both feet). It starts with nothing; Mom gives it the Wooden Sword.

To make a new item:

1. Duplicate `scenes/equipment/basic_sword.tscn` (or make a new scene with a Node3D root).
2. Make sure the root node has `scripts/equipment_item.gd`, pick its **Slot**, and set
   **Damage** (weapons), **Defense** (armor), **Bonus Hearts**, or **Can Chop** (axes).
3. Build its look from shapes or a 3D model, facing forward (-Z) with its center at the origin.
4. In code, call `player.equip(preload("res://scenes/equipment/your_item.tscn"))`, for example
   when the corgi opens a treasure chest.

## Next steps

- Swap the shape-corgi for a real animated model (e.g. the Shiba Inu from Quaternius' free animal pack, or a custom one made in Blender).
- A treasure chest with a better sword or armor inside.
- More quests from the villagers.
- Island 3! (Captain Salty sails using `travel_requested` and `_on_travel_requested()` in `scripts/main.gd`.)
- A dodge roll and a lock-on camera.
