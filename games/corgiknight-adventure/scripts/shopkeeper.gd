extends "res://scripts/villager.gd"
## The shopkeeper. Buys your extra Slime Jelly and Wood, and sells gear.
##
## Add things to sell in the Inspector: put the item scene in "Stock" and
## its price (in coins) at the same spot in "Prices".

@export var stock: Array[PackedScene] = []
@export var prices: Array[int] = []
## The shop's name, shown on the shop menu.
@export var shop_name := ""
## What they say the first time you visit. Leave empty for the usual welcome.
@export var greeting := ""

var _greeted := false
## Name, slot and description of each item for sale (read once at start).
var _info: Array[Dictionary] = []


func _ready() -> void:
	super()
	for scene in stock:
		var item := scene.instantiate() as EquipmentItem
		_info.append({
			"name": item.display_name,
			"slot": item.slot,
			"description": item.describe(),
		})
		item.free()


func interact(_player_node: Node) -> void:
	_talking = true
	var first_time := greeting
	if first_time == "":
		first_time = "Welcome to %s's Shop!|I buy Slime Jelly and Wood, and I sell the finest gear on the island." % npc_name
	var text := "Back again? Let's see what you've got!"
	if not _greeted:
		text = first_time
		_greeted = true
	Game.say(npc_name, Array(text.split("|")), _open_shop)


func _open_shop() -> void:
	Game.shop_requested.emit(self)


func close_shop() -> void:
	_talking = false


# ---------------------------------------------------------------- Buying & selling

func item_count() -> int:
	return stock.size()


## Info for the shop menu: name, price, description, owned.
func item_info(index: int) -> Dictionary:
	var info := _info[index].duplicate()
	info["price"] = prices[index] if index < prices.size() else 999
	info["owned"] = Game.owned.has(stock[index].resource_path)
	info["worn"] = info["owned"] and _is_worn(index)
	return info


## Is the corgi wearing / carrying this item right now?
func _is_worn(index: int) -> bool:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	var path := stock[index].resource_path
	if _info[index]["slot"] == "weapon":
		return (player.get("weapons") as Array).has(stock[index])
	var equipped: Dictionary = player.get("equipped")
	var item: Node = equipped.get(_info[index]["slot"])
	return item != null and is_instance_valid(item) and item.scene_file_path == path


## Sell every extra Slime Jelly (or Wood). Returns what the shopkeeper says.
func sell_all(kind: String) -> String:
	var amount: int = Game.sellable(kind)
	var item_name: String = Game.ITEM_NAMES[kind]
	if amount <= 0:
		if Game.quest_item() == kind:
			return "Keep that %s for your mom's quest, friend!" % item_name
		return "You don't have any %s to sell." % item_name
	var earned: int = amount * Game.SELL_PRICES[kind]
	Game.remove_item(kind, amount)
	Game.add_coins(earned)
	return "%d %s? Here's %d coins. Pleasure doing business!" % [amount, item_name, earned]


## Buy item number `index`. Returns what the shopkeeper says.
func buy(index: int) -> String:
	var info := item_info(index)
	if info["worn"]:
		return "You already have the %s!" % info["name"]
	if info["owned"]:
		var wearer := get_tree().get_first_node_in_group("player")
		if wearer:
			wearer.call("equip", stock[index])
		return "Putting your %s back on. Looking sharp!" % info["name"]
	var price: int = info["price"]
	if Game.coins < price:
		return "The %s costs %d coins. You need %d more!" % [info["name"], price, price - Game.coins]
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return "Hmm, where did you go?"
	Game.add_coins(-price)
	Game.owned.append(stock[index].resource_path)
	if info["slot"] == "weapon":
		player.call("give_weapon", stock[index])
	else:
		player.call("equip", stock[index])
	Game.item_received.emit(str(info["name"]))
	Game.notify_owned()
	return "Here's your %s. It looks great on you!" % info["name"]
