OilConfig = {}

OilConfig.CollectTime = 10000
OilConfig.ProcessTime = 10
OilConfig.ProcessChance = 0.10
OilConfig.ActiveSpots = 1
OilConfig.ActiveTimer = 3600000
OilConfig.Radius = 500

OilConfig.Price = 20

OilConfig.Spots = {
    vector3(536.11,712.93,117.97)
}

OilConfig.ProcessNpcs = {
    {vector3(486.11,706.33,117.31),260.48} -- v3, heading
}
OilConfig.ProcessSpots = {
    vector3(492.14,709.1,117.33)
}

OilConfig.SellNpcs = {
    {vector3(2652.1,-1564.68,46.3),173.83} -- v3, heading
}

OilConfig.SellSpots = {
    vector3(2652.1,-1566.99,46.3)
}

OilConfig.Options = {
    MinMoney = 5,
    MaxMoney = 30,
    MinItemAmount = 1,
    MaxItemAmount = 4,
}

OilConfig.Prompts = {
    Title = "Prospect Tool",
    StopPrompt = 0x5966D52A,
    StopName = "Stop",
    DigPrompt = 0x39336A4F,
    DigName = "Prospect",
}
OilConfig.Towns = {
    `Tumbleweed`,
    `VANHORN`,
    `valentine`, 
    `Strawberry`, 
    `StDenis`, 
    `Emerald`, 
    `Rhodes`, 
    `Blackwater`,  
    `Armadillo`, 
}

OilConfig.Messages = {
    Title = "Prospect",
    WrongArea = "You cant dig in towns!",
    Nothing = "You found nothing!",
    FoundMoney = "You dig up some oil",
    FoundItem = "You dig up some oil",
    NoDig = "You can not dig right now!",
}
