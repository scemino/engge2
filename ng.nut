print("rnd1: " + random(0, 180) + "\n")
print("rnd2: " + random(100.0, 150.0) + "\n")
print("chr(36): " + chr(36) + "\n")

RobotArmsHall <-
{
 background = "RobotArmsHall"
 _armsTID = null
 enter = function()
 {
  //startRobots()
 }

 script waveArm(num) {
  local claw = RobotArmsHall["robotArm"+num+"Claw"]
  local _jointSID = 0
  //actorSound(claw, 2, soundRobotHallClaws1, soundRobotHallClaws2, soundRobotHallClaws3, soundRobotHallClaws4, soundRobotHallClaws5)
  playObjectState(claw, "snap")
  local mult = 1
  if (num == 2 || num == 4) {
  mult = -mult
  }
  local dur = random(0.8,1.1)
  local forearm = RobotArmsHall["robotArm"+num+"_1"]
  local joint = RobotArmsHall["robotArm"+num+"Joint1"]
  objectRotateTo(forearm, 40*mult, dur, SWING)
  objectRotateTo(joint, -40*mult, dur, SWING)
  joint.TID = startthread(@() {
  do {
  //joint.SID = playObjectSound(randomfrom(soundAngryRobotArmSwing1, soundAngryRobotArmSwing2, soundAngryRobotArmSwing3, soundAngryRobotArmSwing4, soundAngryRobotArmSwing5), forearm)
  joint.SID = 0
  soundVolume(joint.SID, 1.2-(num*0.2))
  breaktime(dur)
  fadeOutSound(_jointSID, 0.25)
  }
  })			
  
  do {
  local time = random(0.15, 0.25)
  objectRotateTo(claw, random(-30, 30), time)
  breaktime(time)
  
  }
  }

 function startRobots() {
  RobotArmsHall._armsTID = array(4,NO)
  for (local i = 1; i <= 4; i += 1) {
  RobotArmsHall._armsTID[i-1] = startthread(RobotArmsHall.waveArm, i)
  }
}

robotArm1Joint1 =
 {
 name = ""
 SID = 0
 TID = 0
 }

 robotArm2Joint1 =
 {
 name = ""
 SID = 0
 TID = 0
 }
 robotArm3Joint1 =
 {
 name = ""
 SID = 0
 TID = 0
 }
 robotArm4Joint1 =
 {
 name = ""
 SID = 0
 TID = 0
 }

}
defineRoom(RobotArmsHall)

print("SWING: "+SWING+"\n")

startglobalthread(@()
 {
  cameraInRoom(RobotArmsHall)
})