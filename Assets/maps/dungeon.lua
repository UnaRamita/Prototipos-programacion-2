return {
  version = "1.9",
  luaversion = "5.1",
  tiledversion = "1.10.2",
  orientation = "orthogonal",
  renderorder = "right-down",
  width = 29,
  height = 12,
  tilewidth = 16,
  tileheight = 16,
  nextlayerid = 4,
  nextobjectid = 24,
  properties = {},
  tilesets = {
    {
      name = "Dungeon_Tileset",
      firstgid = 1,
      tilewidth = 16,
      tileheight = 16,
      spacing = 0,
      margin = 0,
      columns = 10,
      image = "../dungeon/Dungeon_Tileset.png",
      imagewidth = 160,
      imageheight = 160,
      tileoffset = { x = 0, y = 0 },
      grid = { orientation = "orthogonal", width = 16, height = 16 },
      properties = {},
      terrains = {},
      tilecount = 100,
      tiles = {
        { id = 0, properties = { ["collidable"] = true } },
        { id = 1, properties = { ["collidable"] = true } },
        { id = 2, properties = { ["collidable"] = true } },
        { id = 3, properties = { ["collidable"] = true } },
        { id = 4, properties = { ["collidable"] = true } },
        { id = 5, properties = { ["collidable"] = true } },
        { id = 20, properties = { ["collidable"] = true } },
        { id = 25, properties = { ["collidable"] = true } },
        { id = 40, properties = { ["collidable"] = true } },
        { id = 41, properties = { ["collidable"] = true } },
        { id = 42, properties = { ["collidable"] = true } },
        { id = 43, properties = { ["collidable"] = true } },
        { id = 44, properties = { ["collidable"] = true } },
        { id = 45, properties = { ["collidable"] = true } },
      }
    }
  },
  layers = {
    {
      type = "tilelayer",
      id = 1,
      name = "Suelo",
      x = 0, y = 0, width = 29, height = 12,
      visible = true, opacity = 1, offsetx = 0, offsety = 0,
      parallaxx = 1, parallaxy = 1, properties = {},
      encoding = "lua",
      data = {
        0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,33,33,33,33,33,25,33,33,33,33,33,33,0,33,33,33,33,33,33,25,33,33,33,33,33,33,25,0,0,33,33,33,33,25,33,33,33,33,33,33,25,0,33,33,33,33,33,25,33,33,33,33,33,33,25,33,0,0,33,33,33,25,33,33,33,33,33,33,25,33,0,33,33,33,33,25,33,33,33,33,33,33,25,33,33,0,0,33,33,25,33,33,33,33,33,33,25,33,33,33,33,33,33,25,33,33,33,33,33,33,25,33,33,33,0,0,33,25,33,33,33,33,33,33,25,33,33,33,33,33,33,25,33,33,33,33,33,33,25,33,33,33,33,0,0,25,33,33,33,33,33,33,25,33,33,33,33,33,33,25,33,33,33,33,33,33,25,33,33,33,33,33,0,0,33,33,33,33,33,33,25,33,33,33,33,33,0,25,33,33,33,33,33,33,25,33,33,33,33,33,33,0,0,33,33,33,33,33,25,33,33,33,33,33,33,0,33,33,33,33,33,33,25,33,33,33,33,33,33,25,0,0,33,33,33,33,25,33,33,33,33,33,33,25,0,33,33,33,33,33,25,33,33,33,33,33,33,25,33,0,0,33,33,33,25,33,33,33,33,33,33,25,33,0,33,33,33,33,25,33,33,33,33,33,33,25,33,33,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
      }
    },
    {
      type = "tilelayer",
      id = 2,
      name = "Paredes",
      x = 0, y = 0, width = 29, height = 12,
      visible = true, opacity = 1, offsetx = 0, offsety = 0,
      parallaxx = 1, parallaxy = 1, properties = {},
      encoding = "lua",
      data = {
        1,2,3,4,5,2,3,4,5,2,3,4,5,2,3,4,5,2,3,4,5,2,3,4,5,2,3,4,6,21,0,0,0,0,0,0,0,0,0,0,0,0,21,0,0,0,0,0,0,0,0,0,0,0,0,0,0,26,21,0,0,0,0,0,0,0,0,0,0,0,0,21,0,0,0,0,0,0,0,0,0,0,0,0,0,0,26,21,0,0,0,0,0,0,0,0,0,0,0,0,21,0,0,21,0,0,0,0,0,0,0,0,0,0,0,26,21,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,21,0,0,0,0,0,0,0,0,0,0,0,26,21,0,0,0,0,0,43,43,43,0,0,0,0,0,0,0,21,0,0,0,0,0,0,0,0,0,0,0,26,21,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,21,0,0,0,0,0,0,0,0,0,0,0,26,21,0,0,0,0,0,0,0,0,0,0,0,0,21,0,0,0,0,0,0,0,0,0,0,0,0,0,0,26,21,0,0,0,0,0,0,0,0,0,0,0,0,21,0,0,0,0,0,0,0,43,43,43,43,0,0,0,26,21,0,0,0,0,0,0,0,0,0,0,0,0,21,0,0,0,0,0,0,0,0,0,0,0,0,0,0,26,21,0,0,0,0,0,0,0,0,0,0,0,0,21,0,0,0,0,0,0,0,0,0,0,0,0,0,0,26,41,42,43,44,45,42,43,44,45,42,43,44,45,42,43,44,45,42,43,44,45,42,43,44,45,42,43,44,46
      }
    },
    {
      type = "objectgroup",
      id = 3,
      name = "Objetos",
      visible = true, opacity = 1, offsetx = 0, offsety = 0,
      parallaxx = 1, parallaxy = 1, properties = {},
      draworder = "topdown",
      x = 0, y = 0,
      objects = {
        { id = 2, name = "", type = "player_spawn", shape = "point", x = 40, y = 128, width = 0, height = 0, rotation = 0, visible = true, properties = {  } },
        { id = 3, name = "", type = "enemy_spawn", shape = "point", x = 88, y = 48, width = 0, height = 0, rotation = 0, visible = true, properties = { ["room"] = 1 } },
        { id = 4, name = "", type = "enemy_spawn", shape = "point", x = 152, y = 144, width = 0, height = 0, rotation = 0, visible = true, properties = { ["room"] = 1 } },
        { id = 5, name = "", type = "enemy_spawn", shape = "point", x = 56, y = 160, width = 0, height = 0, rotation = 0, visible = true, properties = { ["room"] = 1 } },
        { id = 6, name = "", type = "enemy_spawn", shape = "point", x = 248, y = 144, width = 0, height = 0, rotation = 0, visible = true, properties = { ["room"] = 2 } },
        { id = 7, name = "", type = "enemy_spawn", shape = "point", x = 312, y = 48, width = 0, height = 0, rotation = 0, visible = true, properties = { ["room"] = 2 } },
        { id = 8, name = "", type = "enemy_spawn", shape = "point", x = 408, y = 160, width = 0, height = 0, rotation = 0, visible = true, properties = { ["room"] = 2 } },
        { id = 9, name = "", type = "enemy_spawn", shape = "point", x = 424, y = 64, width = 0, height = 0, rotation = 0, visible = true, properties = { ["room"] = 2 } },
        { id = 10, name = "", type = "enemy_spawn", shape = "point", x = 376, y = 96, width = 0, height = 0, rotation = 0, visible = true, properties = { ["room"] = 2 } },
        { id = 11, name = "", type = "chest", shape = "point", x = 424, y = 160, width = 0, height = 0, rotation = 0, visible = true, properties = {  } },
        { id = 12, name = "", type = "key_spawn", shape = "point", x = 328, y = 112, width = 0, height = 0, rotation = 0, visible = true, properties = {  } },
        { id = 21, name = "", type = "heal_spawn", shape = "point", x = 440, y = 160, width = 0, height = 0, rotation = 0, visible = true, properties = {  } },
        { id = 13, name = "", type = "candle", shape = "point", x = 40, y = 48, width = 0, height = 0, rotation = 0, visible = true, properties = { ["room"] = 1 } },
        { id = 14, name = "", type = "candle", shape = "point", x = 184, y = 160, width = 0, height = 0, rotation = 0, visible = true, properties = { ["room"] = 1 } },
        { id = 15, name = "", type = "candle", shape = "point", x = 248, y = 48, width = 0, height = 0, rotation = 0, visible = true, properties = { ["room"] = 2 } },
        { id = 16, name = "", type = "candle", shape = "point", x = 424, y = 48, width = 0, height = 0, rotation = 0, visible = true, properties = { ["room"] = 2 } },
        { id = 17, name = "", type = "candle", shape = "point", x = 248, y = 160, width = 0, height = 0, rotation = 0, visible = true, properties = { ["room"] = 2 } },
        { id = 18, name = "", type = "candle", shape = "point", x = 392, y = 160, width = 0, height = 0, rotation = 0, visible = true, properties = { ["room"] = 2 } },
        { id = 19, name = "", type = "candle", shape = "point", x = 328, y = 96, width = 0, height = 0, rotation = 0, visible = true, properties = { ["room"] = 2 } },
        { id = 20, name = "", type = "door", shape = "rectangle", x = 208, y = 64, width = 16, height = 48, rotation = 0, visible = true, properties = {  } },
        { id = 22, name = "", type = "enemy_spawn", shape = "point", x = 136, y = 40, width = 0, height = 0, rotation = 0, visible = true, properties = { ["room"] = 1, ["enemy"] = "vampire" } },
        { id = 23, name = "", type = "enemy_spawn", shape = "point", x = 304, y = 100, width = 0, height = 0, rotation = 0, visible = true, properties = { ["room"] = 2, ["enemy"] = "vampire" } },
      }
    }
  }
}
