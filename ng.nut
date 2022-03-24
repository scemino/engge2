print("rnd1: " + random(0, 180) + "\n")
print("rnd2: " + random(100.0, 150.0) + "\n")
print("chr(36): " + chr(36) + "\n")

function hideAll() {
  foreach(obj in this) { if (isObject(obj)) { objectHidden(obj, YES) }}
}

function waveReed(reed) {
  local speed_min = 0.75
  local speed_max = 1.0
  objectHidden(reed, NO)
  //objectShader(reed, YES, GRASS_BACKANDFORTH, random(3.0,5.0), random(speed_min,speed_max), YES)
  }

script twinkleStar(obj, fadeRange1, fadeRange2, alphaRange1, alphaRange2) {
  local timeOff, timeOn, fadeIn, fadeOut
  //print("twinkleStar\n")
  objectAlpha(obj, randomfrom(alphaRange1, alphaRange2))
  if (randomOdds(1.0)) {
    do {
      fadeIn = random(fadeRange1, fadeRange2)
      objectAlphaTo(obj, alphaRange2, fadeIn)
      breaktime(fadeIn)
      fadeOut = random(fadeRange1, fadeRange2)
      objectAlphaTo(obj, alphaRange1, fadeOut)
      breaktime(fadeOut)
    }
  }
}

Opening <-
{
 background = "Opening"
 enter = function()
 {
    print("Room entered\n")
    hideAll()
 }

 playOpening = function() {
    return startglobalthread(@() {
      objectHidden(opening1987, NO)
      roomFade(FADE_IN, 2.0)
      breaktime(4.0)
      roomFade(FADE_OUT, 2.0)
      breaktime(2.0)
      hideAll()
      breaktime(2.0)
  
      objectHidden(openingLightBackground, NO)
      objectHidden(openingLight, NO)

      for (local i = 1; i <= 3; i += 1) {
        local star = Opening["openingStar"+i]
        objectHidden(star, NO)
        
        star.tid <- startthread(twinkleStar, star, 0.1, 0.5, random(0.5,1.0), random(0.5, 1))
      }

      for (local i = 4; i <= 16; i += 1) {
        local star = Opening["openingStar"+i]
        objectHidden(star, NO)
        
        star.tid <- startthread(twinkleStar, star, 0.1, 0.5, random(0.5,1.0), random(0.1, 0.5))
      }
      
      roomFade(FADE_IN, 3.0)
      breaktime(3.0)

      local tid = startthread(@() {
        do {
        objectState(openingLight, 1)
        //playSound(soundTowerLight)
        breaktime(2.5)
        objectState(openingLight, 0)
        //playSound(soundTowerLight2)
        breaktime(1.0)
        }
        })
        breaktime(10.0)
       
        //fadeOutSound(sid, 3.0)
        stopthread(tid)
        roomFade(FADE_OUT, 3.0)
        breaktime(3.0)
        hideAll()
       
        for (local i = 1; i <= 16; i += 1) {
        local star = Opening["openingStar"+i]
        objectHidden(star, YES)
        stopthread(star.tid)
        }	
       
        
        objectHidden(openingFenceBackground, NO)
        objectHidden(openingChain, NO)
        objectHidden(openingLock, NO)
        objectState(openingLock, 0)
       
        //sid = loopSound(soundWindBirds, -1, 3.0)
        roomFade(FADE_IN, 3.0)
        breaktime(1.0)

        playObjectState(openingLock, 1)

        //playSound(soundFenceLockRattle)
        breaktime(1.0)

        playObjectState(openingLock, 1)

        breaktime(1.0)

        breaktime(1.0)

        playObjectState(openingLock, 1)

        breaktime(1.0)

        playObjectState(openingLock, 1)

        breaktime(1.0)

        //fadeOutSound(sid, 3.0)
        //fadeOutSound(soundFenceLockRattle, 3.0)
        roomFade(FADE_OUT, 3.0)

        breaktime(1.0)

        playObjectState(openingLock, 1)

        breaktime(1.0)

        playObjectState(openingLock, 1)

        breaktime(1.0)

        breaktime(1.0)
        hideAll()

        
        objectHidden(openingSignBackground, NO)
        objectHidden(openingSign, NO)
        objectHidden(openingPop, NO)
        objectHidden(openingThimbleweedParkText, NO)
        objectHidden(openingCityLimitText, NO)
        objectHidden(openingElevationText, NO)

        for (local i = 1; i <= 3; i += 1) {
        local star = Opening["openingStarA"+i]
        objectHidden(star, NO)
        
        star.tid <- startthread(twinkleStar, star, 0.01, 0.1, random(0,0.3), random(0.6, 1))
        }	
        for (local i = 1; i <= 1; i += 1) {
        local star = Opening["openingStarAB"+i]
        objectHidden(star, NO)
        
        star.tid <- startthread(twinkleStar, star, 0.05, 0.3, 0, 1)
        }	

        waveReed(openingReeds1)
        waveReed(openingReeds2)
        waveReed(openingReeds3)
        waveReed(openingReeds4)
        waveReed(openingReeds5)
        waveReed(openingReeds6)
        waveReed(openingReeds7)
        waveReed(openingReeds8)
        waveReed(openingReeds9)

        roomFade(FADE_IN, 5.0)
        breaktime(1.0)
        //loopSound(soundCricketsLoop, -1, 2.0)
        breaktime(2.0)
        objectHidden(openingBulletHole, YES)
        objectState(openingPop, 0)
        breaktime(5.0)
        //playSound(soundGunshot)
        //stopSound(soundCricketsLoop)
        objectHidden(openingBulletHole, NO)
        breaktime(3.0)
        //playSound(soundMetalClank)
        objectState(openingPop, 1);
        breaktime(3.0)
        roomFade(FADE_OUT, 2.0)
        breaktime(3.0)
        hideAll()
    })
 }

 openingSign = { name = "openingSign" }
 openingPop = { name = "openingPop" }
 openingBulletHole = { name = "openingBulletHole" }
 opening1987 = { name = "opening1987" }
}

defineRoom(Opening)

Opening.playOpening()
