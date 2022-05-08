print("rnd1: " + random(0, 180) + "\n")
print("rnd2: " + random(100.0, 150.0) + "\n")
print("chr(36): " + chr(36) + "\n")

const defaultTextOffset = 90

soundTowerLight <- defineSound("TowerLight.wav")
soundTowerLight2 <- defineSound("TowerLight2.wav")
soundWindBirds <- defineSound("WindBirds.ogg")
soundFenceLockRattle <- defineSound("FenceLockRattle.ogg")
soundCricketsLoop <- defineSound("AmbNightCrickets_Loop.ogg")	
soundGunshot <- defineSound("Gunshot.wav")
soundMetalClank <- defineSound("MetalClank.wav")
soundTowerHum <- defineSound("TowerHum.wav")
soundTitleStinger1 <- defineSound("TitleCardStab1.ogg")
soundTitleStinger2 <- defineSound("TitleCardStab2.ogg")
soundTitleStinger3 <- defineSound("TitleCardStab3.ogg")
soundTitleStinger4 <- defineSound("TitleCardStab4.ogg")
soundDrinkWhisky <- defineSound("DrinkWhisky.wav")	
soundDrip1 <- defineSound("Drip1.wav")					
soundDrip2 <- defineSound("Drip2.wav")					
soundDrip3 <- defineSound("Drip3.wav")					

musicBridgeA <- defineSound("Highway_Bridge_A.ogg")
musicBridgeB <- defineSound("Highway_Bridge_B.ogg")
musicBridgeC <- defineSound("Highway_Bridge_C.ogg")
musicBridgeD <- defineSound("Highway_Bridge_D.ogg")
musicBridgeE <- defineSound("Highway_Bridge_E.ogg")
bridgeMusicPool <- [ musicBridgeA, musicBridgeB, musicBridgeC musicBridgeD, musicBridgeE ]

soundBridgeTrain <- defineSound("BridgeTrain.ogg")				

function defineVerbs(slot) {
  setVerb(slot, 0, { verb = VERB_WALKTO, image = "walkto", func = "verbWalkTo", text = "@30011", key = getUserPref("keyWalkTo", "") })
  setVerb(slot, 1, { verb = VERB_OPEN, image = "open",  func = "verbOpen", text = "@30012", key = getUserPref("keyOpen", "@30013") })
  setVerb(slot, 2, { verb = VERB_CLOSE, image = "close",  func = "verbClose", text = "@30014", key = getUserPref("keyClose", "@30015") })
  setVerb(slot, 3, { verb = VERB_GIVE, image = "give",  func = "verbGive", text = "@30016", key = getUserPref("keyGiveTo", "@30017") })
  setVerb(slot, 4, { verb = VERB_PICKUP, image = "pickup",  func = "verbPickUp", text = "@30018", key = getUserPref("keyPickup", "@30019") })
  setVerb(slot, 5, { verb = VERB_LOOKAT, image = "lookat",  func = "verbLookAt", text = "@30020", key = getUserPref("keyLookAt", "@30021") })
  setVerb(slot, 6, { verb = VERB_TALKTO, image = "talkto",  func = "verbTalkTo", text = "@30022", key = getUserPref("keyTalkTo", "@30023") })
  setVerb(slot, 7, { verb = VERB_PUSH, image = "push",  func = "verbPush", text = "@30024", key = getUserPref("keyPush", "@30025") })
  setVerb(slot, 8, { verb = VERB_PULL, image = "pull",  func = "verbPull", text = "@30026", key = getUserPref("keyPull", "@30027") })
  setVerb(slot, 9, { verb = VERB_USE, image = "use",  func = "verbUse", text = "@30028", key = getUserPref("keyUse", "@30029") })
 }

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

script openGate() {
  //inputOff()
  Bridge.bridgeGate.gate_opening = YES
  objectOffsetTo(Bridge.bridgeGate, -60, 0, 2.0, EASE_INOUT)
  objectTouchable(Bridge.bridgeGate, NO)
  objectOffsetTo(Bridge.bridgeGateBack, -60, 0, 2.0, EASE_INOUT)
  objectTouchable(Bridge.bridgeGateBack, NO)
  //playObjectSound(soundGateSlidingOpen, Bridge.bridgeGate)
  Bridge.bridgeGate.gate_state = OPEN
  breaktime(1)
  walkboxHidden("gate", NO)
  Bridge.bridgeGate.gate_opening = NO
  inputOn()
  breaktime(1)
  objectTouchable(Bridge.bridgeGate, YES)
 
  //Tutorial.completeHint(1)
}

script closeGate() {
  if (Bridge.bridgeGate.gate_state == CLOSED) {
  return	
  }
  Bridge.bridgeGate.gate_closing = YES
  Bridge.bridgeGate.gate_state = CLOSED
  walkboxHidden("gate", YES)
  //playObjectSound(soundGateSlidingClosed, Bridge.bridgeGate)
  objectOffsetTo(Bridge.bridgeGate, 0, 0, 2.0, EASE_INOUT)
  objectTouchable(Bridge.bridgeGate, NO)
  objectOffsetTo(Bridge.bridgeGateBack, 0, 0, 2.0, EASE_INOUT)
  objectTouchable(Bridge.bridgeGateBack, NO)
  breaktime(2.0)
  Bridge.bridgeGate.gate_closing = NO
  objectTouchable(Bridge.bridgeGate, YES)
 
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
      local sid = loopSound(soundTowerHum, -1, 1.0)
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
      
      roomFade(FADE_IN, 1.0)
      breaktime(1.0)

      local tid = startthread(@() {
        do {
        objectState(openingLight, 1)
        playSound(soundTowerLight)
        breaktime(2.5)
        objectState(openingLight, 0)
        playSound(soundTowerLight2)
        breaktime(1.0)
        }
        })
        breaktime(10.0)
       
      fadeOutSound(sid, 3.0)
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
      
      sid = loopSound(soundWindBirds, -1, 3.0)
      roomFade(FADE_IN, 3.0)
      breaktime(1.0)

      playObjectState(openingLock, 1)

      playSound(soundFenceLockRattle)
      breaktime(1.0)

      playObjectState(openingLock, 1)

      breaktime(1.0)

      breaktime(1.0)

      playObjectState(openingLock, 1)

      breaktime(1.0)

      playObjectState(openingLock, 1)

      breaktime(1.0)

      fadeOutSound(sid, 3.0)
      fadeOutSound(soundFenceLockRattle, 3.0)
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
      loopSound(soundCricketsLoop, -1, 2.0)
      breaktime(2.0)
      objectHidden(openingBulletHole, YES)
      objectState(openingPop, 0)
      breaktime(5.0)
      playSound(soundGunshot)
      stopSound(soundCricketsLoop)
      objectHidden(openingBulletHole, NO)
      breaktime(3.0)
      playSound(soundMetalClank)
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
 stopAllSounds()
 stopMusic(0.10)
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
 playSound(randomfrom(soundTitleStinger1, soundTitleStinger2, soundTitleStinger3, soundTitleStinger4))
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

boris <- {
  _key = "boris"
  name = "@30072"
  fullname = "@30073"
  icon = "icon_boris"
  detective = NO
  flags = PERSON|MALE
  onLadder = NO
 
  function showHideLayers() {
    actorHideLayer(boris, "splash")
  }
 }

 function borisCostume()
 {
  actorCostume(boris, "BorisAnimation")
  actorWalkSpeed(boris, 30, 15)
  actorRenderOffset(boris, 0, 45)
  actorTalkColors(boris, talkColorBoris)
  actorTalkOffset(boris, 0, defaultTextOffset)
  actorHidden(boris, OFF)
  //objectLit(boris, 1)
  //footstepsNormal(boris)
  boris.showHideLayers()
 }

createActor(boris)
addSelectableActor(6, boris)
actorSlotSelectable(6, YES)
defineVerbs(6)
verbUIColors(6, {	nameid = "boris", sentence = 0xffffff, 
 verbNormal = 0x3ea4b5, verbHighlight = 0x4fd0e6,
 verbNormalTint = 0x4ebbb5, verbHighlightTint = 0x96ece0, 
 inventoryFrame = 0x009fdb, inventoryBackground = 0x002432 })
actorVolume(boris, 0.7)
// addSelectableActor(6, boris)
// setActorDefaults(boris)
// actorSlotSelectable(6, YES)
// defineVerbs(6)
// verbUIColors(6, {	nameid = "boris", sentence = 0xffffff, 
//  verbNormal = 0x3ea4b5, verbHighlight = 0x4fd0e6,
//  verbNormalTint = 0x4ebbb5, verbHighlightTint = 0x96ece0, 
//  inventoryFrame = 0x009fdb, inventoryBackground = 0x002432 })
borisCostume()

willie <- { 
  _key = "willie"
  name = "willie"
 }

createActor(willie)
actorCostume(willie, "WillieSittingAnimation")

script flashAlphaObject(obj, offRange1, offRange2, onRange1, onRange2, fadeRange1, fadeRange2, maxFade = 1.0, minFade = 0.0) {
  local timeOff, timeOn, fadeIn, fadeOut
  objectAlpha(obj, randomfrom(0.0, 1.0))
  do {
  timeOff = random(offRange1, offRange2)
  breaktime(timeOff)
  fadeIn = random(fadeRange1, fadeRange2)
  objectAlphaTo(obj, maxFade, fadeIn)
  breaktime(fadeIn)
  timeOn = random(onRange1, onRange2)
  breaktime(timeOn)
  fadeOut = random(fadeRange1, fadeRange2)
  objectAlphaTo(obj, minFade, fadeOut)
  breaktime(fadeOut)
  }
 }

script animateFirefly(obj) {
  startthread(flashAlphaObject, obj, 1, 4, 0.5, 2, 0.1, 0.35)
  }

function createFirefly(x) {
  local firefly = 0
  local zsort = 68
  local y = random(78,168)
  local direction = randomfrom(-360,360)
  if (y < 108) {
  firefly = createObject("firefly_large")
  zsort = random(68,78)
  } else
  if (y < 218) {
  firefly = createObject("firefly_small")
  zsort = 117
  } else
  if (x > 628 && x < 874) {		
  firefly = createObject("firefly_tiny")
  zsort = 668
  }
  if (firefly) {
  objectRotateTo(firefly, direction, 12, LOOPING)
  objectAt(firefly, x, y)
  objectSort(firefly, zsort)
  return firefly
  }
  }

Bridge <- 
{
 background = "Bridge"

 script trainPassby() {
  objectOffset(Bridge.bridgeTrain, -100, 0)
  objectOffsetTo(Bridge.bridgeTrain, 2000, 0, 10, LINEAR)
  playSound(soundBridgeTrain)
 }

 show = function() {
  return startglobalthread(@() {
    actorAt(boris, Bridge.borisStartSpot)
    actorFace(boris, FACE_RIGHT)
    // pickupObject(borisNote, boris)
    // pickupObject(borisWallet, boris)
    // pickupObject(borisHotelKeycard, boris)
    // pickupObject(borisPrototypeToy, boris)
    //startMusic(musicBridgeA, bridgeMusicPool)
    cameraInRoom(Bridge)
    selectActor(boris)
    //breaktime(3.0)

    sayLine(boris, "@40123", "@40124")

    // Bridge.bridgeGate.gate_state = CLOSED
    objectState(bridgeBody, GONE)
    objectState(bridgeBottle, GONE)
    objectState(bridgeChainsaw, GONE)
    objectTouchable(bridgeGateBack, YES)
    //objectTouchable(bridgeGate, NO)
    objectTouchable(bridgeGate, YES)
    actorCostume(willie, "WilliePassedOutAnimation")
    actorRenderOffset(willie, 0, 45)
    actorUseWalkboxes(willie, NO)
    actorLockFacing(willie, FACE_RIGHT)
    objectHotspot(willie, -28,0,20,50)
    actorAt(willie, Bridge.willieSpot)
    //actorUsePos(willie, Bridge.willieTalkSpot)
    //willie.dialog = "WillieBorisDialog"
    actorPlayAnimation(willie, "awake")
    objectState(Bridge.willieObject, HERE)
    objectTouchable(Bridge.willieObject, YES)
    
    // actorWalkTo(boris, Bridge.bridgeGateBack)
    // breakwhilewalking()
    // cameraAt(700,86)
    cameraAt(210,86)
    roomFade(FADE_IN, 2)
    breaktime(6)
    // cameraPanTo(210, 86, 12, EASE_INOUT)
    startthread(Bridge.trainPassby)
    breaktime(2)
    breaktime(12.0)
    actorPlayAnimation(willie, "drink")
    breakwhileanimating(willie)
    actorPlayAnimation(willie, "awake")
    breaktime(2)
    actorWalkTo(boris, Bridge.bridgeGateBack)
    breakwhilewalking(boris)
    sayLine(boris, "@40124")
    //cameraFollow(boris)
    //breaktime(1.0)
    //breakwhiletalking(boris)
       
    breaktime(10000)
  })
 }

 enter = function() 
 {
    objectTouchable(bridgeHighwayDoorOpening, YES)
    objectState(Bridge.willieObject, HERE)
    objectTouchable(Bridge.willieObject, YES)
    
    objectTouchable(bridgeHighwayDoorOpening, YES)
    objectState(Bridge.willieObject, HERE)
    objectTouchable(Bridge.willieObject, YES)
  for (local x = 0; x < 960; x += random(20, 40)) {		
    local firefly = createFirefly(x)
    if (firefly) {
    startthread(animateFirefly, firefly)
    }		
    }
    for (local x = 1150; x < 2140; x += random(30, 50)) {		
    local firefly = createFirefly(x)
    if (firefly) {
    startthread(animateFirefly, firefly)
    }		
    }
    objectParallaxLayer(bridgeWater, 1)
    loopObjectState(bridgeWater, 0)
    loopObjectState(bridgeShoreline, 0)
    actorSound(bridgeSewerDrip, 2, soundDrip1, soundDrip2, soundDrip3)
    loopObjectState(bridgeSewerDrip, 0)
    objectParallaxLayer(bridgeTrain, 2)
    objectParallaxLayer(frontWavingReeds1, -2)
    objectParallaxLayer(frontWavingReeds2, -2)
    objectParallaxLayer(frontWavingReeds3, -2)
    local star = 0
    for (local i = 1; i <= 28; i += 1) {
      star = Bridge["bridgeStar"+i]
      objectParallaxLayer(star, 5)
      startthread(twinkleStar, star, 0.01, 0.1, random(0,0.3), random(0.6, 1))
    }	
    for (local i = 1; i <= 5; i += 1) {
      star = Bridge["bridgeStarB"+i]
      objectParallaxLayer(star, 5)
      startthread(twinkleStar, star, 0.05, 0.3, 0, 1)
    }
    objectOffset(Bridge.bridgeTrain, -100, 0)
 }

 bridgeGate =
 {
 gate_state = CLOSED
 gate_opening = NO
 gate_closing = NO
 useDist = 20
 name = "gate"
 defaultVerb = VERB_OPEN
 verbOpen = function() 
 {
  if (gate_state == OPEN) {
    sayLine(boris, "@25680")
  } else {
    startthread(openGate)
    defaultVerb = VERB_CLOSE
  }
 }

 verbClose = function() 
 {
  sayLine(boris, "@25681")
 if (gate_state == CLOSED && gate_closing == NO) {
 //noReach()
 if (isBoris()) {
 sayLine(boris, "@25681")
 } else {
 //sayLineAlreadyClosed(this)
 }
 } else {
 startthread(closeGate)
 defaultVerb = VERB_OPEN
 }
 }
}
}
defineRoom(Bridge)

startglobalthread(@()
 {
  // breakwhilerunning(Opening.playOpening())
  // breakwhilerunning(TitleCards.showPartMeeting())
  breakwhilerunning(Bridge.show())
})