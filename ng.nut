script bounceImage(sheet)
{
    local image = createObject(sheet,["fstand_bodyA1"])
    local x = random(0, 320)
    local y = random(0, 180)

    do
    {
        local steps = random(100.0, 150.0)

        local end_x = random(0, 320)
        local end_y = random(0, 180)

        local dx = (end_x - x) / steps
        local dy = (end_y - y) / steps

        for (local i = 0; i < steps; i++)
        {
            x += dx
            y += dy
            objectAt(image, x, y)
            breakhere(1)
        }
    }
}

print("rnd1: " + random(0, 180) + "\n")
print("rnd2: " + random(100.0, 150.0) + "\n")

for (local i = 1 ; i <= 10 ; i++) 
{
  startglobalthread(bounceImage, "RaySheet");
  startglobalthread(bounceImage, "ReyesSheet");
}