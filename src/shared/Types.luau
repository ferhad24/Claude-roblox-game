--!strict
-- Kataloq və oyun vəziyyəti üçün ümumi tip tərifləri.

export type WorkType =
	"leaf"
	| "thread"
	| "branch"
	| "stone_light"
	| "stone_heavy"
	| "glass"
	| "root"
	| "soil"
	| "gather"
export type MasteryBranch = "hand" | "botany" | "mech"
export type ItemCategory = "material" | "water" | "seed" | "campaign" | "memory" | "cargo"
export type ZoneId = string

export type Amount = { id: string, n: number }

-- Şərtlər: kataloq açılmaları, tapşırıq tələbləri və dükan kilidləri üçün kiçik DSL.
export type Condition =
	{ kind: "always" }
	| { kind: "step", step: string } -- tapşırıq addımı tamamlanıb
	| { kind: "chapter", chapter: number } -- fəsil tamamlanıb
	| { kind: "power", value: number }
	| { kind: "zone", zone: ZoneId } -- sahə açılıb
	| { kind: "final" }
	| { kind: "all", list: { Condition } }

export type ItemDef = {
	id: string,
	nameKey: string,
	category: ItemCategory,
	stack: number,
	zone: ZoneId,
	color: { number },
}

export type CupSpec = { capacity: number, spread: number, spreadRadius: number }

export type ToolDef = {
	id: string,
	nameKey: string,
	family: string,
	tier: number,
	price: number,
	unlock: Condition,
	minPower: number,
	rates: { [WorkType]: number },
	cup: CupSpec?,
	cartCapacity: number?,
	mandatory: boolean,
	color: { number },
}

export type WorkDef = {
	id: string,
	nameKey: string,
	work: number,
	workType: WorkType,
	minPower: number,
	mats: { Amount },
	coins: number,
	xp: number,
	mastery: MasteryBranch,
	size: { number },
	color: { number },
	specAdded: boolean?, -- sənəd cədvəlində olmayan, layihədə əlavə edilmiş obyekt
}

-- Su qəbul edən sabit obyektlər (yataqlar, rezervuarlar).
export type ConsumerDef = {
	id: string,
	nameKey: string,
	doses: number, -- bərpa üçün tam doza sayı
	coins: number,
	xp: number,
	mastery: MasteryBranch,
	cupAllowed: boolean,
	requiresPump: boolean,
	bloom: boolean, -- MAT_BLOOM verir (bir dəfə)
	size: { number },
}

export type Port = { x: number, z: number, dir: string } -- "in" | "out"

export type BuildKind =
	"channel"
	| "wheel"
	| "catcher"
	| "bridge"
	| "lift"
	| "pump"
	| "tank"
	| "planter"
	| "compost"
	| "lamp"
	| "sorter"
	| "sprinkler"
	| "decor"

export type BuildVariant = { id: string, footprint: { number }, ports: { Port } }

export type BuildDef = {
	id: string,
	nameKey: string,
	kind: BuildKind,
	limit: number,
	footprint: { number }, -- {x, z} stud, rot=0 üçün
	height: number,
	ports: { Port },
	variants: { BuildVariant }?,
	socketOnly: boolean,
	blocksPath: boolean,
	capacity: number?, -- su tutumu (çən, toplayıcı)
	regenSeconds: number?, -- toplayıcı: 1 doza/regenSeconds
	color: { number },
}

export type RecipeDef = {
	id: string,
	nameKey: string,
	group: string,
	inputs: { Amount },
	output: Amount,
}

export type RecipeGroupDef = {
	id: string,
	nameKey: string,
	zone: ZoneId,
	keyPrice: number,
	unlock: Condition, -- açar alışı (və ya pulsuz açılma) nə vaxt mümkündür
	free: boolean, -- açar pulsuzdur və şərt ödənəndə avtomatik verilir
	recipes: { string },
}

export type PlantDef = {
	id: string,
	nameKey: string,
	seedId: string,
	seedPrice: number,
	growSeconds: number,
	yield: { Amount },
	zone: ZoneId,
	unlock: Condition,
	color: { number },
}

export type DecorDef = {
	id: string,
	nameKey: string,
	price: number,
	unlock: Condition,
	footprint: { number },
	color: { number },
}

export type ZoneDef = {
	id: ZoneId,
	nameKey: string,
	order: number,
	unlock: Condition,
	chapter: number,
	origin: { number },
	size: { number },
	groundColor: { neglected: { number }, partial: { number }, restored: { number } },
}

export type Objective =
	{ type: "restore", ids: { string } }
	| { type: "fillCup" }
	| { type: "water", id: string }
	| { type: "ownTool", tool: string }
	| { type: "interact", id: string }
	| { type: "crafted", item: string, count: number }
	| { type: "buildAtPort", build: string, node: string }
	| { type: "lineConnected", target: string, via: { string }? }
	| { type: "placed", build: string, count: number, zone: ZoneId? }
	| { type: "socket", id: string }
	| { type: "key", group: string }
	| { type: "cargo", target: string, count: number }
	| { type: "planted", count: number }
	| { type: "harvested", species: string?, count: number }
	| { type: "workingPlanters", count: number, zone: ZoneId? }
	| { type: "essences", count: number }
	| { type: "wake" }
	| { type: "power", value: number }
	| { type: "memory", id: string }

export type QuestStep = {
	id: string,
	textKey: string,
	objective: Objective,
	marker: string?, -- xəritə/HUD hədəf obyekti
	bonus: { coins: number?, xp: number?, builds: { Amount }?, items: { Amount }?, seeds: { Amount }? }?,
	unlockGroup: string?, -- addım bitəndə pulsuz açılan resept qrupu
}

export type ChapterDef = {
	chapter: number,
	zone: ZoneId,
	titleKey: string,
	steps: { QuestStep },
	reward: { coins: number, xp: number, badge: string? },
}

export type SideTaskDef = {
	id: string,
	zone: ZoneId,
	textKey: string,
	objective: Objective,
	reward: { coins: number, xp: number },
	marker: string?,
}

export type OrderDef = {
	id: string,
	wants: Amount,
	coins: number,
	xp: number,
	unlock: Condition,
}

export type AchievementDef = {
	id: string,
	nameKey: string,
	coins: number,
}

-- Layout: dünyadakı sabit obyektlərin yerləşməsi.
export type LayoutObject = {
	id: string,
	kind: "work"
		| "consumer"
		| "source"
		| "plot"
		| "spot"
		| "socket"
		| "npc"
		| "storage"
		| "workbench"
		| "shop"
		| "board"
		| "memory"
		| "cargo"
		| "dropoff"
		| "gate"
		| "lamp"
		| "tree"
		| "home",
	def: string?, -- WorkDef/ConsumerDef/BuildDef/NPC id
	zone: ZoneId,
	pos: { number }, -- dünya koordinatı {x, y, z}
	rot: number?, -- dərəcə (Y oxu)
	ports: { Port }?, -- dünya XZ-də obyektin mərkəzinə nisbətən
	spawns: { string }?, -- yuva: yenilənən WorkDef id-ləri
	opens: string?, -- maneə/yuva bitəndə açılan qapı/yol
	blocksPath: boolean?,
	capacity: number?,
	regenSeconds: number?,
	infinite: boolean?,
	target: string?, -- dropoff/gate üçün
	count: number?,
	extra: { [string]: any }?,
}

export type BuildArea = {
	id: string,
	zone: ZoneId,
	origin: { number }, -- künc {x, y, z}; tam ədədlər
	size: { number }, -- {w, d}
}

export type Rect = { x0: number, z0: number, x1: number, z1: number }

export type ZoneLayout = {
	zone: ZoneId,
	objects: { LayoutObject },
	areas: { BuildArea },
	paths: { Rect },
	safeSpawn: { number },
	ground: { { pos: { number }, size: { number }, kind: string? } },
	walls: { { pos: { number }, size: { number }, rot: number?, transparent: boolean? } },
	props: {
		{
			pos: { number },
			size: { number },
			shape: string?,
			color: { number },
			stage: string?,
			rot: number?,
			tilt: number?,
			name: string?,
			collide: boolean?,
		}
	},
	water: { { pos: { number }, size: { number } } },
}

-- Saxlanılan qurğu.
export type PlacedBuild = {
	t: string, -- BuildDef id
	area: string?, -- BuildArea id
	socket: string?, -- sabit yuva id
	x: number,
	z: number,
	r: number, -- 0..3
	v: string?, -- variant
	w: number?, -- su (çən/toplayıcı)
	c: number?, -- kompost/emal taymeri
	rt: number?, -- toplayıcı regen toplayıcısı
}

export type PlantState = {
	sp: string,
	g: number, -- aktiv böyümə saniyələri
	m: number, -- rütubət
	ready: boolean,
	md: number?, -- rütubət azalması üçün toplayıcı
}

export type MasteryState = { marks: number, level: number }

export type Profile = {
	schemaVersion: number,
	createdAt: number,
	coins: number,
	workXP: number,
	mastery: { hand: MasteryState, botany: MasteryState, mech: MasteryState },
	tools: { [string]: boolean },
	equipped: string?,
	hotbar: { string },
	bagCapacity: number,
	bag: { [string]: number },
	pending: { [string]: number },
	storage: { [string]: number },
	campaign: { [string]: number },
	seeds: { [string]: number },
	buildInv: { [string]: number },
	cup: number,
	homeWater: number,
	cargo: { [string]: number },
	groups: { [string]: boolean },
	quest: { chapter: number, step: number, done: { [string]: boolean }, side: { [string]: boolean } },
	oneTimeRewards: { [string]: boolean },
	zones: { [string]: boolean },
	restoredObjectIds: { [string]: boolean },
	workProgress: { [string]: number },
	interacted: { [string]: boolean },
	builds: { [string]: PlacedBuild },
	nextBuildId: number,
	waterSources: { [string]: number },
	waterRegen: { [string]: number },
	moisture: { [string]: number },
	plants: { [string]: PlantState },
	respawn: { [string]: number },
	memories: { [string]: boolean },
	achievements: { [string]: boolean },
	stats: {
		crafted: { [string]: number },
		harvested: { [string]: number },
		planted: number,
		lineDelivered: { [string]: number },
		cargoDelivered: { [string]: number },
		wheelZones: { [string]: boolean },
		dosesByLine: number,
		works: number,
	},
	orders: { offers: { string }, active: string?, seed: number, completed: number },
	settings: { [string]: any },
	playSeconds: number,
	dayTime: number,
	rain: { next: number, untilT: number },
	finalCompleted: boolean,
	finalWatched: number,
}

return {}
