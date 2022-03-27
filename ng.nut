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
      cameraInRoom(Opening)
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

TitleCards <-
{
 background = "TitleCards"
 _dont_hero_track = TRUE

 enter = function()
 {
 ""
 foreach(obj in this) { if (isObject(obj)) { objectHidden(obj, YES) }}
 }

 exit = function()
 {
 }

 script displayCard(part, title) {
 cameraInRoom(TitleCards)
 //stopAllSounds()
 //stopMusic(0.10)
 //stopSoundAmbiance()
 //local state = inputState()
 //inputOff()
 //inputVerbs(OFF)
 objectHidden(pressPreview, YES)
 objectHidden(part, NO)
 objectHidden(title, NO)
 objectHidden(line, NO)
 objectAlpha(part, 1.0)
 objectAlpha(title, 1.0)
 objectAlpha(line, 1.0)
 //playSound(randomfrom(soundTitleStinger1, soundTitleStinger2, soundTitleStinger3, soundTitleStinger4))
 breaktime(5.0)
 objectAlphaTo(part, 0.0, 2.0)
 objectAlphaTo(title, 0.0, 2.0)
 objectAlphaTo(line, 0.0, 2.0)
 breaktime(4.0)
 objectHidden(part, YES)
 objectHidden(title, YES)
 objectHidden(line, YES)
 //inputState(state)
 }

 function showPessPreview() {
 cameraInRoom(TitleCards)
 stopAllSounds()
 stopMusic(0.10)
 stopSoundAmbiance()
 inputOff()
 objectHidden(pressPreview, NO)
 objectScale(pressPreview, 0.5)
 local sid = playSound(randomfrom(soundTitleStinger1, soundTitleStinger2, soundTitleStinger3, soundTitleStinger4))
 startthread(@() {
 breakwhilesound(sid)
 loopSound(musicQuickiePalA)
 })
 }

 
 function showPartMeeting() {
 return startglobalthread(displayCard, part1, part1Title)
 }

 
 function showPartBody() {
 achievementPart(2)
 setProgress("part2")
 logEvent("part2")
 g.part = 2
 return startglobalthread(displayCard, part2, part2Title)
 }

 
 function showPartArrest() {
 achievementPart(3)
 setProgress("part3")
 logEvent("part3")
 g.part = 3
 return startglobalthread(displayCard, part3, part3Title)
 }

 
 function showPartWill() {
 achievementPart(4)
 setProgress("part4")
 logEvent("part4")
 g.part = 4
 return startglobalthread(displayCard, part4, part4Title)
 }

 
 function showPartReading() {
 achievementPart(5)
 setProgress("part5")
 logEvent("part5")
 g.part = 5
 return startglobalthread(displayCard, part5, part5Title)
 }

 
 function showPartFactory() {
 achievementPart(6)
 setProgress("part6")
 logEvent("part6")
 g.part = 6
 return startglobalthread(displayCard, part6, part6Title)
 }

 
 function showPartMadness() {
 achievementPart(7)
 setProgress("part7")
 logEvent("part7")
 g.part = 7
 return startglobalthread(displayCard, part7, part7Title)
 }

 
 function showPartEscape() {
 achievementPart(8)
 setProgress("part8")
 logEvent("part8")
 g.part = 8
 return startglobalthread(displayCard, part8, part8Title)
 }

 
 function showPartDeleting() {
 achievementPart(9)
 setProgress("part9")
 logEvent("part9")
 g.part = 9
 return startglobalthread(displayCard, part9, part9Title)
 }

 
 


}

defineRoom(Opening)
defineRoom(TitleCards)

startglobalthread(@()
 {
  breakwhilerunning(Opening.playOpening())
  breakwhilerunning(TitleCards.showPartMeeting())
})