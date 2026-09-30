-- TSB M1 + DASH AI -- MOBILE VARIANT -- INSTALLER + RUNNER (M6)
-- The only file you need. Execute it every time:
--   workspace copy missing   -> installs it, runs
--   workspace copy different -> replaces it, runs
--   workspace copy identical -> runs from the file
-- Persistence (queue_on_teleport) reuses the exact source that ran.
local FILE = "TSB_M1_Dash_AI_Mobile.lua"
local BODY = [=========[
-- TSB M1 + DASH AI MK.1 -- MOBILE VARIANT (M6, based on REV R22)
-- M6: signed pixel offset for every mobile touchpoint; focused live preview;
--     saves in the mobile layout file and reloads after an automatic rejoin.
-- M5: shared presser (OBJECT under/nearest the point, GLOBAL fake touch to
--     the game's own input listeners, TOUCH last resort), per-button method
--     from the calibrator; latest calibration built in.
-- M4: button lookup skips handler-less layers (the full-screen
--     Hotbar.Backpack frame was being picked for every button); TouchTap added.
-- M3: real mobile input type (UserInputService reads as touch for the game)
--     + buttons pressed through their own handlers: no virtual pointer, no
--     cursor, several buttons can be held at once. Pointer touch = fallback.
-- Same brain as the PC build. Input layer swapped:
--   movement  -> virtual W/A/S/D state -> Humanoid:Move(camera-relative),
--                identical to what the keyboard control module produces (M2)
--   facing    -> shift lock emulated (root yaw follows the camera)
--   Q / F / Space / 1-4 -> touches on the calibrated mobile buttons
--                (TSB_AI_mobile_layout.json, built-in default = your calibration)
--   tools     -> external watchdog unequips any tool left equipped
-- REV R22 notes follow.
-- R22: thumbstick drag goes fully outside the stick circle and releases
--     out there (no return to center); random tap loop unchanged.
-- R21: while dead, nonstop thumbstick drags + random touch taps near the
--     screen center until the character is actually alive.
-- R20: while dead, drag the mobile thumbstick (touch begin/move/end) instead
--     of plain taps; taps only in the short hold after respawn.
-- R19: touch taps (never mouse) on every death until just after respawn,
--     not only during the scripted reset.
-- R18: reset flow switches to the mobile control scheme (touch pulses)
--     until just after respawn, so the new character gets mobile buttons.
-- R17: leaderboard stays hidden across respawns (respawn re-hide, AI-start
--     re-hide, 1 s watchdog).
-- R16: windup interrupts work point-blank (min 1.5 studs) and right after
--     our own blocked M1s (M1 safety wait ignored for the interrupt).
-- R15: re-execution fully stops the previous copy (heartbeat, respawn hook,
--     own animation hook); failed rejoin resumes the AI.
-- R14: windup interrupt windows (close = hit first, far = normal answer),
--     punish Xs before end, M3 -> Flowing Water route, leaderboard hidden.
-- R13: queue payload embeds this script's own source (IY-style single chunk,
--     no file read / download after teleport); faster autostart (1.0 / 0.5 s).
-- R12: no M4 -> Hunter's Grasp; a ragdolled target is walked up to (no dash)
--     and grabbed once settled. Autoexec fallback: flag file + bootstrap
--     (TSB_AI_autoexec_boot.lua) for executors without queue_on_teleport.
-- R11: START and autostart share reset -> bounded respawn wait -> AI on;
--     Hunter's Grasp / ragdoll catch fire only on a landed, settled target.
-- R10: Infinite Yield-compatible persistence. Re-queues on every teleport
--     state and after IY's handler (single-slot executors: last queue wins),
--     payload also reloads IY when IY is running, loader runs once.
-- R9: persistence fixes. Waits for game + LocalPlayer (queued runs start
--     early); loader tries .lua and .txt names and logs every failure;
--     queues before our own rejoin as well as on OnTeleport; panel shows
--     PERSIST: OK / NO FILE / NO QUEUE / OFF.
-- R8: escort model. FlyExperimentTest leads; FatFlyExperimentTest / Bot hover
--     beside it, guard close behind it in its fights, take third parties near
--     it (40-stud leash), rescue when it is low. Leader wins every claim tie.
-- R7: one-on-one team model (claimed enemies, guard post behind the fighting
--     ally, rescue only when the ally is low); death rejoin works for manual
--     sessions and also triggers on Health <= 0.
-- R6: persistence (queue_on_teleport), autostart after teleport (reset ->
--     respawn -> AI on), rejoin same server on death (auto sessions only);
--     move press = key select, delay, screen click, verify, delay, unselect;
--     fixed team roles (name with "fat" flanks / cuts off); file comms.
-- SETUP: save this file in the executor workspace as CONFIG.ScriptFile.
-- R5: animation length fallback (173 logged lengths + runtime cache) so
--     fraction / before-end triggers work before an asset loads; guard drops
--     as soon as the blocked track is cut short (attacker stunned).
-- R4: continuous tracking. Handled tracks re-arm (re-block multi-hits, block
--     a dash that was queued early then dropped); a 0.1s sweep of every
--     nearby enemy's playing tracks catches late-seen / out-of-range starts;
--     incoming dashes are attacks from 26 studs and block on arrival;
--     counter-dash only inside 12 studs and once per dash.
-- R3: M3 finish routes when M3 is confirmed to hit (health drop, no guard):
--     A) LWS instead of M4, B) uppercut -> LWS catch while falling,
--     C) neutral M4 ragdoll -> dash to predicted landing -> HG/LWS/FW catch.
-- R2: Hero Hunter moves (slots 1-3) with press/verify/unselect and
--     self-calibrating cooldowns (FW 17 / LWS 20 / HG 15 seeds); techs:
--     side-dash-M1 (close side dash, M1 on the dash key, continue string),
--     Flowing Water block break, Hunter's Grasp ragdoll pickup.
-- Formerly: TSB_M1_Dash_AI_V1_PRE-ADVANCED_v18
-- CORE (unchanged MK.1): M1 chain, own-M1 tracking, spacing, approach,
-- dash execution, ragdoll chase, M4 follow-up, own-ragdoll escape.
-- R1 (defense + data + team; never takes a frame from a live M1 string):
--   RULES      one per-ID table generated from the annotation file
--   RANGES     one awareness radius for observation; per-rule detect /
--              commit / facing / trigger timing decides whether to act
--   BLOCK      per-rule commit range, hold and max hold
--   THREAT LOCK hold-until-stop moves suppress approach and M1
--   DASH RESERVE offensive dashes never spend the last defensive bucket;
--              evade falls back side -> back -> block -> step
--   READ WINDOW short adaptive wait after a target drops block
--   TEAM       friends are never targeted; allies are coordinated from
--              their observed movement (focus, pincer, rescue, fall back)
-- Shift Lock must already be enabled.
-- PC controls movement, camera, jump, and dash. Only ATK uses the mobile position.

pcall(function()
    if type(_G.__TSBM1DashAICleanup) == "function" then
        _G.__TSBM1DashAICleanup()
    end
end)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

-- R9: a teleport-queued run can start before the game or LocalPlayer exist.
if not game:IsLoaded() then game.Loaded:Wait() end
while not Players.LocalPlayer do task.wait() end
local LocalPlayer = Players.LocalPlayer

local CONFIG = {
    Enabled = false,
    TargetMode = "Closest", -- Closest or Random
    TargetRange = math.huge,
    RetargetIfCloserBy = 12,
    -- Normal M1 spacing: keep the fight between 4 and 6 studs.
    -- 6 is the hard outer limit; below 4 the AI creates space instead
    -- of standing inside the opponent.
    M1MinRange = 4,
    M1Range = 6,
    DashRange = 24,
    DashContactRange = 2,
    SideDashCooldown = 3,
    FrontBackDashCooldown = 5,
    M1SafetyWait = 0.4,
    M1InputGap = 0.04,
    M1ConfirmTimeout = 0.36,
    M4Recovery = 1.0,
    M4DashFollowupWindow = 0.40,
    CameraTurnRate = 0.42,
    M1CommitRange = 6,
    M1BreakRange = 6,
    ApproachDashMinRange = 9,
    ApproachDashMaxRange = 18,
    MoveKeyReassertInterval = 0.10,
    DashBlockGrace = 0.35,
    OwnRagdollRecoveryTime = 0.60,
    OwnRagdollEscapeRetry = 0.15,
    MovementDirectionHysteresis = 0.96,
    MovementCameraHysteresis = 0.985,
    CameraTurnDeadzone = 0.025,
    ApproachUpdateInterval = 0.05,
    EnableDownslam = true,
    EnableUppercut = true,
    EnableBackdashReset = true,
    EnableAutoBlock = true,
    BlockDetectRange = 20,
    BlockRange = 8,
    BlockCircleEnabled = true,
    BlockCircleMaxTime = 0.85,
    BlockCircleDashRange = 10,
    BlockBehindDot = -0.35,
    UseBlockTimings = false,
    BlockLead = 0.02,
    BlockTrail = 0.04,
    BlockHoldTime = 0.20,
    BlockMaxHoldTime = 0.80,
    BlockReachHorizon = 0.50,
    GetupIFrameTime = 0.60,
    ReactionDistance = 22,
    LongThreatDistance = 42,
    ReactionLockout = 0.35,
    ReactionDuplicateWindow = 0.08,
    DashStartTimeout = 0.35,
    DashTimeout = 1.5,
    ActionTimeout = 4.0,
    RagdollPrediction = 0.18,
    RagdollRecheck = 0.12,

    -- R1: two-tier ranges
    AwarenessRadius = 45,
    DynamicLeadTime = 0.18,
    DynamicBonusMax = 6,
    FacingDot = 0.35,
    BlockTriggerLead = 0.12,
    EvadeTriggerLead = 0.06,
    ThreatSafetyTail = 0.25,
    DefaultThreatHold = 3.0,
    AttackBlockMaxCap = 2.5,
    -- R1: dash economy / re-entry
    DashReserveEnabled = true,
    BlockDropReadWindow = 0.12,
    BlockDropReadMin = 0.08,
    BlockDropReadMax = 0.28,
    ReentryPunishWindow = 0.60,
    -- R1: anti-predictability (movement only; M1 timing untouched)
    StrafeVariance = true,
    StrafeFlipMin = 0.6,
    StrafeFlipMax = 1.4,
    ApproachDashJitter = true,
    -- R1: enemies other than the current target
    ExternalThreats = true,
    ExternalRetargetRange = 9,
    -- R1: team. Matched against DisplayName and Name (case-insensitive).
    TeamEnabled = true,
    TeamProtected = {"John Bumblcat", "HARPSEALking101"},       -- never attacked
    TeamAllies = {"FlyExperimentTest", "FatFlyExperimentTest", "Bot"}, -- never attacked + coordinated
    CoopWithProtected = false,  -- true = also defend/focus alongside John Bumblcat
    TeamScanInterval = 0.10,
    AllyEngageRange = 12,
    AllyPressureRange = 9,
    FocusBonus = 15,
    RescueBonus = 25,
    BackstabBonus = 8,
    PincerOffset = 5,
    PincerStartRange = 14,
    FriendSeparation = 4.5,
    FriendlyFireCone = 0.72,
    AllyBlockFacingRange = 9,
    LowHealthRatio = 0.35,
    FallbackRange = 60,

    -- R2: moves (Hero Hunter, slots 1-3; slot 4 counter unused)
    MovesEnabled = true,
    TechsEnabled = true,
    MoveVerifyWindow = 0.35,   -- own move animation must start within this
    MoveRetryDelay = 1.0,      -- after a press that did not start the move
    MoveUnselectMode = "IF_EQUIPPED", -- IF_EQUIPPED | ALWAYS | NEVER
    MoveSelectDelay = 0.08,    -- R6: after the slot key, let the server equip the tool
    MoveUnselectDelay = 0.10,  -- R6: after the move starts, before unselecting
    MoveRequireTool = true,    -- R6: no equipped tool after select = stunned/dead, abort
    -- R2: techs
    TechSideDashM1Chance = 0.70, -- neutral entry vs a target facing us
    TechCloseMin = 2.5,
    TechCloseMax = 7,
    TechM1MinRange = 1.5,      -- M1 min range while continuing a tech string
    FWBreakRange = 7,
    HGRange = 6,
    -- R3: M3 finish routes (only when M3 is confirmed to have hit)
    FinishRoutesEnabled = true,
    RouteWeightLWSAfterM3 = 0.35, -- M3 hit -> Lethal Whirlwind Stream
    RouteWeightUpperAir = 0.25,   -- M3 hit -> uppercut -> LWS catch while falling
    RouteWeightNeutralCatch = 0.15, -- M3 hit -> neutral M4 ragdoll -> dash -> catch
    M3HitWaitMax = 0.30,
    AirCatchTimeout = 1.4,
    AirCatchFallSpeed = 2,
    AirCatchHeight = 5.5,     -- root height above ground to fire the catch
    AirCatchRange = 6,
    RagdollCatchHeight = 3.5,
    RagdollCatchRange = 6,
    LWSRange = 6,
    InterruptRange = 7,        -- R14: interrupt-window hits only inside this distance
    RouteWeightFWAfterM3 = 0.25, -- R14: M3 hit -> Flowing Water
    -- R4: continuous threat tracking
    DashThreatDetect = 26,     -- an incoming dash is an attack from this far
    DashBehindMaxRange = 12,   -- only counter-dash a dash that is already close
    WatchRearmDelay = 0.15,    -- re-evaluate a handled track after this
    TrackScanInterval = 0.10,  -- sweep playing tracks for anything missed
    TrackScanRadius = 60,
    -- R5: early stop (attacker stunned / cancelled)
    EarlyStopMargin = 0.15,    -- stopped this far before its length = cut short
    EarlyStopRelease = 0.05,   -- guard kept this long after a cut-short track

    -- R6: persistence / autostart / rejoin
    PersistEnabled = true,     -- re-queue this script on every teleport
    ScriptFile = "TSB_M1_Dash_AI_Mobile.lua", -- executor workspace copy of THIS file
    ScriptUrl = "",            -- optional raw URL fallback (HttpGet)
    AutoStartDelay = 1.0,      -- after an auto-load, before the self reset (R13: was 3.0)
    AutoEnableDelay = 0.5,     -- after respawn, before the AI switches on (R13: was 1.5)
    EmbedSourceInQueue = true, -- R13: queue our own source text (IY-style, no file read after teleport)
    AutoShiftLock = false,     -- mobile: shift lock is emulated instead
    MobileLayoutFile = "TSB_AI_mobile_layout.json",
    EmulateShiftLock = true,   -- root yaw follows the camera while the AI runs
    ToolWatchdog = true,       -- unequip tools the AI did not mean to hold
    ToolUnexpectedGrace = 0.35,
    SpoofTouchInput = true,    -- M3: game sees a touch device (no virtual pointer, no cursor)
    DirectButtons = true,      -- M3: press mobile buttons through their own handlers
    RejoinOnDeath = true,      -- auto-started session: death rejoins the same server
    -- R6: team roles + file comms
    CutOffLead = 7,            -- flanker aims this far ahead of a running target
    FlankStartRange = 30,
    FileComms = true,          -- same-PC bots share state through executor files
    CommsFolder = "TSB_AI_Comms",
    PersistStatus = "?",
    HGWalkup = true,           -- R12: ragdolled target + HG ready = walk up, grab when settled (never M4 -> HG)
    HGWalkupStop = 3.5,        -- R12: stop walking this close
    AutoexecFallback = true,   -- R12: also write an autostart flag + autoexec bootstrap file
    HideLeaderboard = true,    -- R14: player list off so it does not block the screen
    MobileControlsOnReset = true, -- R18: touch input during reset so the respawn builds mobile buttons
    MobileTouchPoint = {0.5, 0.18}, -- R18: screen fraction for the harmless touch pulses (empty sky area)
    MobileHoldAfterSpawn = 1.0,  -- R18: keep pulsing this long after the new character appears
    ThumbstickPoint = {0.15, 0.78}, -- R20: fallback thumbstick zone (screen fraction, bottom-left)
    ThumbstickDragDistance = 120,   -- R22: minimum drag length in pixels
    ThumbstickOvershoot = 1.8,      -- R22: drag to this x the stick radius (well outside the circle)
    ThumbstickFallbackRadius = 0.09, -- R22: stick radius guess (x screen height) when no stick is found
    ThumbstickDragSteps = 6,
    MiddleTapSpread = 0.15,         -- R21: random taps within +/-15% of screen center
    DeadInputGap = 0.03,            -- R21: pause between drag+tap rounds while dead
    StartWithReset = true,     -- R11: START resets you, AI takes over after respawn
    RespawnTimeout = 12,       -- R11: give up waiting for a respawn and enable anyway
    HGMinRagdollTime = 0.30,   -- R11: target must have been down this long
    HGMaxHeight = 2.6,         -- R11: target root this close to the ground (lying)
    HGMaxVerticalSpeed = 4,
    HGMaxSlideSpeed = 10,      -- R11: still sliding faster than this = not landed
    ChainInfiniteYield = true, -- R10: if IY is running, our queued loader also reloads IY
    InfiniteYieldUrl = "https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source",
    CommsInterval = 0.2,
    CommsStaleMs = 1000,
    -- R7: one fights, one guards (no 2v1 on the same enemy)
    OneOnOne = true,
    GuardDistance = 16,        -- guard sits this far behind the fighting ally
    GuardMinEnemyDistance = 14,
    GuardRescueLowHealth = true, -- join only when the fighting ally is low and pressured
    ThreatToAllyRange = 20,    -- unclaimed enemy this close to an ally = priority
    ThreatToAllyBonus = 10,
    SelfDefenseHold = 3.0,     -- a claimed enemy that attacks us is ours for this long
    RejoinManualSessions = true, -- death rejoin also in manually started sessions
    -- R8: escort model. The leader fights normally; every other roster bot
    -- (FatFlyExperimentTest, Bot) hovers near the leader and only takes
    -- fights near them, steps in on third parties, or rescues.
    TeamLeader = "FlyExperimentTest",
    EscortHoverSide = 9,       -- hover offset beside the leader
    EscortHoverBack = 3,       -- ...and slightly behind
    EscortGuardDistance = 10,  -- post behind the leader while the leader fights
    EscortLeash = 40,          -- escorts ignore enemies farther than this from the leader
}

-- Hardcoded from the supplied Mobile Attack Button Position Logger output.
local ATTACK_BUTTON = {
    AbsoluteCenter = Vector2.new(1073, 378),
    -- The previous request moved the tap 100 pixels down. Move it back
    -- by half of that request: original + 8, then + 50 = +58.
    InputOffset = Vector2.new(0, 58),
}

local M1_SETS = {
    {10469493270, 10469630950, 10469639222, 10469643643},
    {13532562418, 13532600125, 13532604085, 13294471966}, -- R1: stage 4 corrected (was a repeat of stage 1)
    {13491635433, 13296577783, 13295919399, 13295936866},
    {13370310513, 13390230973, 13378751717, 13378708199},
    {14004222985, 13997092940, 14001963401, 14136436157},
    {15259161390, 15240216931, 15240176873, 15162694192}, -- R1: stage 3/4 corrected; 15271263467 is IGNORE
    {16515503507, 16515520431, 16515448089, 16552234590},
    {17889458563, 17889461810, 17889471098, 17889290569},
    {123005629431309, 100059874351664, 104895379416342, 134775406437626}, -- R1: set 9 added
    {}, -- set 10: slot preserved, no verified IDs supplied yet
    {125361499827663, 105701432344953, 104293439261333, 114460992057353}, -- set 11
    {124962465789551, 111644455066361, 112778933066374, 80488470577181}, -- set 11 variant
}

local M1_TIMINGS = {
    [10469493270]=0.198,[10469630950]=0.167,[10469639222]=0.247,[10469643643]=0.182,
    [13532562418]=0.148,[13532600125]=0.181,[13532604085]=0.215,
    [13491635433]=0.181,[13296577783]=0.265,[13295919399]=0.281,[13295936866]=0.314,
    [13370310513]=0.239,[13390230973]=0.301,[13378751717]=0.256,[13378708199]=0.214,
    [14004222985]=0.215,[13997092940]=0.316,[15259161390]=0.249,[15240216931]=0.197,
    [15162694192]=0.247,[16515503507]=0.147,[16515520431]=0.167,[16515448089]=0.248,
    [16552234590]=0.182,[17889458563]=0.180,[17889461810]=0.172,[17889471098]=0.239,
    [17889290569]=0.213,[100059874351664]=0.164,[123005629431309]=0.181,
    [104895379416342]=0.232,[134775406437626]=0.249,[13379003796]=0.431,
}

local DASH_IDS = {
    [10479335397]=true, -- verified front dash
    [10480793962]=true, -- left
    [10480796021]=true, -- right
    [10491993682]=true, -- back
}

local DOWNSLAM_IDS = {[10470104242]=true}
local UPPERCUT_IDS = {[10503381238]=true, [13379003796]=true}
local BLOCK_ANIMATION_ID = 10470389827

-- R1 RULES: the single per-ID decision table.
-- Generated from TSB_M1_Dash_AI_Reaction_Decisions_V1_Updated (annotation wins on
-- every conflict). Unlisted IDs are ignored. Fields:
--   mode      BLOCK | BLOCK_OR_SIDE | SIDE_DASH | BACK_DASH | RETREAT | NO_ATTACK
--             INTERRUPT | INTERRUPT_OR_SIDE | PUNISH
--   detect    arming distance (studs); closing speed can extend it slightly
--   blockRange  block commit distance (default CONFIG.BlockRange)
--   hold / blockMax   minimum / maximum block hold
--   maxHold   threat-lock cap for evasive / no-attack modes
--   trigAt / trigFrac / trigEnd   act at time, fraction, or seconds-before-end
--   untilStop hold the reaction (no re-entry) until the track stops
--   facing    only when the attacker faces us
--   punish    M1 chain when the track stops (normal attack gate applies)
local RULES = {
    [12272894215] = {mode="SIDE_DASH", detect=12, untilStop=true}, -- Flowing water, short range, not blockable, count
    [12342141464] = {mode="RETREAT", detect=42, maxHold=5, untilStop=true}, -- This is ult, does aoe damage.
    [12460977270] = {mode="SIDE_DASH", detect=12, untilStop=true}, -- This is flowing water, not blockable but counter
    [12463072679] = {mode="RETREAT", detect=22, maxHold=4, untilStop=true}, -- This is final hunt not counterable or dogeable.
    [14057231976] = {mode="SIDE_DASH", detect=12, untilStop=true}, -- This is rock splitting fist not blockable but co
    [13630786846] = {mode="SIDE_DASH", detect=22, untilStop=true}, -- This is lethal dash counterable but not blockabl
    [12534735382] = {mode="BLOCK", detect=20, hold=0.45, blockMax=2.45}, -- Machine gun blows,  counter and blockable.
    [12502664044] = {mode="SIDE_DASH", detect=20, untilStop=true}, -- Dash from machine gun bursts, only the backside 
    [12509505723] = {mode="BLOCK", detect=12, hold=0.45, blockMax=1.20}, -- Main attack from machine gun blows as you can bl
    [12618292188] = {mode="BLOCK", detect=8, hold=0.30}, -- End animation of blitz shot can technically be b
    [12684390285] = {mode="SIDE_DASH", detect=12, untilStop=true}, -- Jet dive animation
    [12684185971] = {mode="PUNISH", punish=true}, -- End animation of blitz dive.
    [12772543293] = {mode="RETREAT", detect=30, maxHold=4, untilStop=true}, -- Ult does a bit of knockback
    [14721837245] = {mode="RETREAT", detect=22, maxHold=4, untilStop=true}, -- At close to end of end animation move far at abo
    [12832505612] = {mode="SIDE_DASH", detect=22, untilStop=true}, -- Speedblitz, just dodge. Cannot block or counter.
    [13083332742] = {mode="SIDE_DASH", detect=40, untilStop=true, facing=true}, -- Flameware cannon, long range, cannot do either b
    [13146710762] = {mode="SIDE_DASH", detect=30, untilStop=true, facing=true}, -- Incinerate, cannot block or counter 160 degree c
    [13376869471] = {mode="BLOCK", detect=12, hold=0.80, blockMax=1.30}, -- Flash strike, far ish range, can blcok and count
    [13294790250] = {mode="SIDE_DASH", detect=12, untilStop=true, facing=true}, -- If this hits you it will slow you down as it tel
    [13376962659] = {mode="BLOCK", detect=8, hold=0.70, blockMax=0.85}, -- Scatter, should constantly block if see this as 
    [13365849295] = {mode="PUNISH", punish=true}, -- End animation of scatter.
    [13501296372] = {mode="SIDE_DASH", detect=20, untilStop=true, facing=true}, -- Explosive shurikin, unless aimed directly at you
    [13556985475] = {mode="SIDE_DASH", detect=20, untilStop=true, facing=true}, -- Air variant of shurikin, same logic but in air s
    [13379404053] = {mode="RETREAT", detect=22, maxHold=4, untilStop=true}, -- If this animation is playing it is middle animat
    [13499771836] = {mode="RETREAT", detect=42, maxHold=5, untilStop=true}, -- Starting ult animation for sonic
    [13497875049] = {mode="PUNISH", punish=true}, -- Landing animation for sonic ult
    [13632347366] = {mode="SIDE_DASH", detect=20, untilStop=true}, -- Twin blade rush which is a rush try to dodge can
    [13639700348] = {mode="SIDE_DASH", detect=20, untilStop=true}, -- At start of animation quickly dodge,  cannot blo
    [13723174078] = {mode="SIDE_DASH", detect=30, untilStop=true}, -- Carnage, far range move going up as dodge in gen
    [13881335713] = {mode="SIDE_DASH", detect=20, trigFrac=0.75, untilStop=true}, -- Starting animation of fourfold strike, dodge at 
    [13876406148] = {mode="PUNISH", punish=true}, -- End of aniamtion, use this time to attack.
    [13380255751] = {mode="SIDE_DASH", detect=20, untilStop=true}, -- Dash animation for sonic,
    [14004235777] = {mode="INTERRUPT", detect=8}, -- First variant of home run, close range, cannot b
    [14003607057] = {mode="BACK_DASH", detect=8, untilStop=true}, -- Second variant of home run, if missed dashes and
    [14046756619] = {mode="SIDE_DASH", detect=8, untilStop=true}, -- Beatdown if it hits, useless. But should try to 
    [14048349132] = {mode="BLOCK", detect=8, hold=0.30}, -- Beatdown, dashes, can block and counter, do it i
    [14299135500] = {mode="BACK_DASH", detect=10, untilStop=true}, -- Grand slam, at close to end if ontop of you plea
    [14967219354] = {mode="PUNISH", punish=true}, -- End of grand slam animation,
    [14351441234] = {mode="SIDE_DASH", detect=12, untilStop=true}, -- At 2/4 of animation is actual hit  it is a jump 
    [14733282425] = {mode="RETREAT", detect=30, maxHold=4, untilStop=true}, -- Metal bat ult, does small aoe,
    [14719290328] = {mode="RETREAT", detect=20, maxHold=5, untilStop=true}, -- Savage tornado, just try to run, cannot block or
    [14701242661] = {mode="RETREAT", detect=20, maxHold=5, untilStop=true}, -- Same as savage tornado can end early if you hit 
    [14900168720] = {mode="BACK_DASH", detect=12, trigFrac=0.72, untilStop=true}, -- Strength diffrence, cannot block or counter, mov
    [15128849047] = {mode="RETREAT", detect=22, maxHold=4, untilStop=true}, -- Death blow, is a counter to you which kills you 
    [15134211820] = {mode="PUNISH", punish=true}, -- The actual hit from death blow if missed.
    [15290930205] = {mode="BLOCK", detect=8, hold=0.55, trigAt=0.50}, -- Quick slice, moves back and then does several sl
    [15145462680] = {mode="SIDE_DASH", detect=8, untilStop=true}, -- Similar to pin point cut.  Jsut no dash before a
    [15295895753] = {mode="BACK_DASH", detect=8, untilStop=true}, -- Pin point cut, at 0.5s dashes forward and deals 
    [15295336270] = {mode="SIDE_DASH", detect=8, trigAt=0.35, untilStop=true}, -- Same as pin pint cut but air variant as they go 
    [15311685628] = {mode="NO_ATTACK", maxHold=3, untilStop=true}, -- This is a counter, do not hit them.
    [15391323441] = {mode="RETREAT", detect=30, maxHold=5, untilStop=true}, -- Ult, does aoe flame which goes outward at end.
    [15520132233] = {mode="RETREAT", detect=30, maxHold=8, untilStop=true}, -- Sunset, slashes flames as they move forward in d
    [15676072469] = {mode="SIDE_DASH", detect=20, untilStop=true}, -- Solar dash, cannot block or counter.
    [16062410809] = {mode="SIDE_DASH", detect=20, trigAt=0.20, untilStop=true}, -- Sunrise, dashes, can end early in 0,2s window if
    [16082123712] = {mode="RETREAT", detect=42, maxHold=5, untilStop=true}, -- Atomic slash, maybe big, instant kill if in rang
    [16139108718] = {mode="BLOCK", detect=30, blockRange=30, hold=0.50, facing=true}, -- Crushing pull, if looking at yiy immedelty block
    [16515850153] = {mode="BLOCK_OR_SIDE", detect=20, hold=0.80}, -- Windstorm fury within 0.2s can cancel them else 
    [16431491215] = {mode="SIDE_DASH", detect=12, untilStop=true}, -- Stone coffin, makes stone that crushes opponent 
    [16597912086] = {mode="INTERRUPT", detect=8}, -- If they do this animation next to you hit them o
    [16734584478] = {mode="RETREAT", detect=42, maxHold=6, untilStop=true}, -- Beserk ult, just run immedelty, far
    [16737255386] = {mode="RETREAT", detect=42, maxHold=6, untilStop=true}, -- Cosmic straight if see immedelty run far additio
    [17464644182] = {mode="RETREAT", detect=30, maxHold=5, untilStop=true}, -- If see start of this anim just run cannot block 
    [17450393107] = {mode="SIDE_DASH", detect=12, untilStop=true}, -- idk just dodge out cannot run or block
    [17275150809] = {mode="BLOCK", detect=30, blockRange=30, hold=0.50, facing=true}, -- If see this animation and they looking at you an
    [17860467628] = {mode="SIDE_DASH", detect=20, untilStop=true}, -- Sky catcher, far moving dash move, dodge for dur
    [17799224866] = {mode="BLOCK", detect=8, hold=0.50, blockMax=2.80}, -- Bullet barage, not enough clearance to stop so j
    [17838006839] = {mode="BACK_DASH", detect=8, untilStop=true}, -- Vanishing kick, dash move if they very close to 
    [17838619895] = {mode="INTERRUPT", detect=8}, -- Chain move for vanishing kick, if they use it im
    [18179181663] = {mode="BACK_DASH", detect=8, untilStop=true}, -- Headfirst, close up, if they  use it dash away i
    [18435535291] = {mode="RETREAT", detect=42, maxHold=5, untilStop=true}, -- Ult, just run aoe,
    [18435383478] = {mode="SIDE_DASH", detect=12, untilStop=true}, -- Hit of grand fissure,
    [129651400898906] = {mode="RETREAT", detect=30, maxHold=3, untilStop=true}, -- Grand fissure, cannot block or counter, just run
    [18897119503] = {mode="SIDE_DASH", detect=30, untilStop=true}, -- If you see this move being used move to the side
    [106755459092436] = {mode="INTERRUPT", detect=30, trigAt=1.0}, -- Last breath windup, atleast hit at 1s unde max,
    [132259592388175] = {mode="RETREAT", detect=30, maxHold=5, untilStop=true}, -- Last breath after windup,  cannot block or count
    [95575238948327] = {mode="RETREAT", detect=30, maxHold=5, untilStop=true}, -- Same as last breath after windup.
    [102814369422840] = {mode="RETREAT", detect=30, maxHold=5, untilStop=true}, -- Same as last breath after windup.
    [113166426814229] = {mode="INTERRUPT_OR_SIDE", detect=20, trigAt=0.30}, -- Weboom, creates a spider that moves toward you a
    [116753755471636] = {mode="NO_ATTACK", detect=40, maxHold=4, untilStop=true}, -- Windup of  plasma  cannon,  not recommended to h
    [116153572280464] = {mode="NO_ATTACK", detect=40, maxHold=4, untilStop=true}, -- Also windup of p,as ass cannon,
    [114095570398448] = {mode="SIDE_DASH", detect=20, untilStop=true}, -- Probably when it fires. Not sure, can counter no
    [77509627104305] = {mode="BLOCK", detect=12, blockRange=12, hold=0.50}, -- Trinity tear, moves forward and if it gets close
    [98542310119798] = {mode="INTERRUPT", detect=8, trigEnd=0.40}, -- Landing anim of it, when at there try to hit the
    [91353107056596] = {mode="RETREAT", detect=20, maxHold=4, untilStop=true}, -- Jump anim of twin burst just run.
    [71852503410610] = {mode="RETREAT", detect=20, maxHold=4, untilStop=true}, -- First shot of twin burst just run cannot block o
    [96558273957850] = {mode="RETREAT", detect=20, maxHold=4, untilStop=true}, -- Second shot of twin burst cannot lock or counter
    [140620736290884] = {mode="BACK_DASH", detect=12, untilStop=true}, -- Trinity tear going down, cannot block or counter
    [99938926876557] = {mode="INTERRUPT", detect=8}, -- Landing animation of Trinity tear landing advise
    [105616370132258] = {mode="RETREAT", detect=42, maxHold=6, untilStop=true}, -- Ult, jsut run can steer, massive aoe
    [101588604872680] = {mode="SIDE_DASH", detect=20, untilStop=true}, -- Fly animation of doomdive,
    [102989537449083] = {mode="SIDE_DASH", detect=12, untilStop=true}, -- Dice animation of doom dive, counter if uptop or
    [105442749844047] = {mode="INTERRUPT", detect=8}, -- Starting animation of crowd buster, hit them.
    [131820095363270] = {mode="BLOCK", detect=12, blockRange=12, hold=0.50, blockMax=2.55, punish=true}, -- Crowd buster actual attack . Block or counter if
    [109617620932970] = {mode="INTERRUPT", detect=8}, -- Hammer heel, best to counter if close up.
    [135289891173395] = {mode="INTERRUPT_OR_SIDE", detect=8}, -- Air vainst of hammer heel, can try to dash out b
    [125955606488863] = {mode="BLOCK", detect=8, hold=0.80}, -- Binding cloth can try to hit immedelty but 0.2s 
    [97401167464229] = {mode="RETREAT", detect=42, maxHold=6, untilStop=true}, -- Ult, goes extremely far in  multiple dashes, try
    [85025226664507] = {mode="BACK_DASH", detect=14, untilStop=true}, -- Hunters mark, try to dodge and can hit you withi
    [84363696088617] = {mode="RETREAT", detect=42, maxHold=6, untilStop=true}, -- Great fajin, cannot block or dodge hit  within 0
    [71317401437256] = {mode="RETREAT", detect=42, maxHold=5, untilStop=true}, -- Second hit anim of great fajin, also extends ver
    [107484339495811] = {mode="BACK_DASH", detect=22, untilStop=true}, -- God slayer, move back a bit far, cannot block or
    [136465810903839] = {mode="SIDE_DASH", detect=20, trigAt=0.50, untilStop=true}, -- Sky rippling fist, can end in first 0.5s else th
    [117726521294150] = {mode="SIDE_DASH", detect=12, untilStop=true, facing=true}, -- Grave Digger-related animation. Close range, can
    [121535378064818] = {mode="SIDE_DASH", detect=12, untilStop=true, facing=true}, -- Grave Digger. Close range, cannot be blocked, ca
    [118270485922095] = {mode="NO_ATTACK", maxHold=3, untilStop=true}, -- Crossfire, a counter.

    -- Blast Breaker: set 11 M4 + far forward projectile. Wide, facing-gated block.
    [114460992057353] = {mode="BLOCK", detect=30, blockRange=30, hold=0.50, facing=true},
    -- Target downslam finisher: never block, get out of it.
    [10470104242] = {mode="SIDE_DASH", detect=10, untilStop=true},

    -- UNVERIFIED: MK.1 legacy IDs absent from the annotation file. Kept at
    -- their MK.1 behavior until you annotate them.
    [10468665991] = {mode="BLOCK", detect=30, blockRange=30, hold=0.50, blockMax=1.20, unverified=true},
    [12296882427] = {mode="BLOCK", detect=32, blockRange=24, hold=0.60, blockMax=2.00, unverified=true}, -- fight log: connects at 22.5
    [12296113986] = {mode="BLOCK", detect=32, blockRange=24, hold=0.60, blockMax=2.00, unverified=true}, -- partner track of the above
    [10466974800] = {mode="BLOCK_OR_SIDE", detect=20, unverified=true},
    [15957361339] = {mode="BLOCK_OR_SIDE", detect=20, unverified=true},
    [17857788598] = {mode="BLOCK_OR_SIDE", detect=20, unverified=true},
    [17857880283] = {mode="BLOCK_OR_SIDE", detect=20, unverified=true},
    [10471336737] = {mode="SIDE_DASH", detect=22, unverified=true},
    [12510170988] = {mode="SIDE_DASH", detect=22, unverified=true},
    [13927612951] = {mode="SIDE_DASH", detect=22, unverified=true},
    [111986840437684] = {mode="SIDE_DASH", detect=22, unverified=true},
    [11365563255] = {mode="RETREAT", detect=42, maxHold=0.35, unverified=true},
    [12983333733] = {mode="RETREAT", detect=42, maxHold=0.35, unverified=true},
}
-- Counters: NO_ATTACK locks already cover them; flagged for the status panel.
-- R14 interrupt windows: "hit them during the windup / within Xs you can
-- end it early". Inside M1 reach and inside the window the AI hits first;
-- otherwise the rule's normal answer (block / dodge / retreat) applies.
for id, window in pairs({
    [16515850153] = 0.20,  -- Windstorm Fury: cancel within 0.2s
    [125955606488863] = 0.20, -- Binding Cloth: 0.2s hit window
    [16062410809] = 0.40,  -- Sunrise: window is 0.4
    [136465810903839] = 0.50, -- Sky Rippling Fist: end it in the first 0.5s
    [129651400898906] = 0.50, -- Grand Fissure: 0.5s windup
    [18897119503] = 0.50,  -- 30-stud catch move: 0.5s windup
    [14719290328] = 0.80,  -- Savage Tornado: 0.8s window
    [14701242661] = 0.80,  -- Savage Tornado variant ("only 1 window")
}) do
    if RULES[id] then RULES[id].interruptWindow = window end
end
-- Presumed Normal Punch (legacy ID, unverified): heavy up close, weaker far.
-- Close = hit it during the windup; far = block.
if RULES[10468665991] then RULES[10468665991].interruptWindow = 0.35 end

-- R14 punish before end: "stops attacking Xs before the animation ends /
-- hit them Xs before it ends" -> end the guard/lock and attack then.
for id, before in pairs({
    [131820095363270] = 0.40, -- Crowd Buster
    [107484339495811] = 0.40, -- God Slayer
    [15290930205] = 0.40,     -- Quick Slice
    [15295895753] = 0.40,     -- Pin Point Cut
}) do
    if RULES[id] then RULES[id].punishBeforeEnd = before end
end

for _, id in ipairs({15311685628, 15128849047, 118270485922095}) do
    if RULES[id] then RULES[id].counter = true end
end

local function setOf(list)
    local result = {}
    for _, id in ipairs(list) do result[id] = true end
    return result
end

local M1_IDS = {}
local M1_INFO_BY_ID = {}
for setIndex, set in ipairs(M1_SETS) do
    for stage, id in ipairs(set) do
        M1_IDS[id] = true
        M1_INFO_BY_ID[id] = M1_INFO_BY_ID[id] or {}
        table.insert(M1_INFO_BY_ID[id], {setIndex = setIndex, stage = stage})
    end
end

local M1_BY_FIRST_DIGIT = {}
for id in pairs(M1_IDS) do
    local first = tostring(id):sub(1, 1)
    M1_BY_FIRST_DIGIT[first] = M1_BY_FIRST_DIGIT[first] or {}
    M1_BY_FIRST_DIGIT[first][id] = true
end

-- Block kind is derived: M1s and uppercuts block as M1, dashes as DASH, and
-- BLOCK / BLOCK_OR_SIDE rules as ATTACK. Any other rule removes blockability
-- (the annotation said it cannot be blocked).
local BLOCK_KIND_BY_ID = {}
for id in pairs(M1_IDS) do BLOCK_KIND_BY_ID[id] = "M1" end
for id in pairs(UPPERCUT_IDS) do BLOCK_KIND_BY_ID[id] = "M1" end
for id in pairs(DASH_IDS) do BLOCK_KIND_BY_ID[id] = "DASH" end
for id, rule in pairs(RULES) do
    if rule.mode == "BLOCK" or rule.mode == "BLOCK_OR_SIDE" then
        BLOCK_KIND_BY_ID[id] = "ATTACK"
    else
        BLOCK_KIND_BY_ID[id] = nil
    end
end
for id in pairs(DOWNSLAM_IDS) do BLOCK_KIND_BY_ID[id] = nil end

local M1_RULE = {mode = "M1"}
local DASH_RULE = {mode = "DASH", detect = 26} -- R4: dash is an attack (CONFIG.DashThreatDetect)

local Character, Humanoid, Root, Animator
local CurrentTarget, TargetConnection
local TargetConnections = {}
local CurrentTargetCharacter
local TargetTrackSeen = {}
local OwnAnimationConnection
local OwnTrackSeen = {}
local ActiveDashTrack
local ActiveDashStarted = 0
local ActiveOwnM1Track
local LastOwnAnimationId
local LastOwnAnimationAt = 0
local OwnDashSerial = 0
local OwnM1Serial = 0
local OwnM1Stage = 0
local OwnM1SetIndex
local LastOwnM1Id
local LastOwnM1At = 0
local NextM1AllowedAt = 0
local Busy = false
local State = "OFF"
local LastReaction = 0
local LastSideDash = -math.huge
local LastFrontBackDash = -math.huge
local CurrentM1Set
local CurrentM1Stage = 0
local LearnedM1Sequence = {}
local LearnedM1Stage = 0
local LastLearnedM1At = 0
local LastTargetPosition
local LastTargetRagdolled = false
local TargetGetupIFrameUntil = 0
local RagdollComboDone = false
local NextRagdollTry = 0
local ActionGeneration = 0
local PendingReaction
local ActionStartedAt = 0
local LastMoveDirection
local LastMoveForward
local LastMoveRight
local LastMoveMode
local LastMoveKeyReassertAt = 0
local LastOwnDashKind
local LastOwnDashEndedAt = -math.huge
local ActiveOwnDashKind
local PendingBlock
local BlockTrack
local BlockId
local BlockKind
local BlockStartedAt = 0
local BlockExpectedEnd = 0
local IsBlocking = false
local TargetBlockTrack
local TargetIsBlocking = false
local TargetBlockStartedAt = 0
local LastBlockCircleReactionAt = -math.huge
local BlockCircleSideSign
local clearTargetBlockState
local NextApproachUpdate = 0
local M4FollowupActive = false
local LastOwnRagdolled = false
local OwnRagdollEscapeTried = false
local OwnRagdollEscapeSucceeded = false
local OwnRagdollEscapeRetryAt = 0
local OwnRagdollRecoveryUntil = 0
local OwnRagdollEscapeKind

-- R1 state and functions live in two tables to stay under the Luau
-- 200-local limit of the main chunk.
local RS = {
    ThreatWatches = {},        -- [track] = watch
    ThreatLock = nil,
    TargetBlockEndedAt = -math.huge,
    ReentryAt = -math.huge,
    BlockDropWindow = CONFIG.BlockDropReadWindow,
    BlockMaxHold = nil,
    ChainLive = false,
    StrafeFlipSign = 1,
    NextStrafeFlipAt = 0,
    ApproachDashRoll = nil,
    AllyIntent = {},
    NextTeamScan = 0,
    ExternalConnections = {},
    NextTrackScan = 0,
    -- R5: animation lengths. Logged lengths from the annotation file are the
    -- fallback while an asset has not loaded on this client (Length == 0);
    -- real lengths seen at runtime are cached over them.
    LengthCache = {[14516273501]=8.9667, [7807831448]=0.6667, [7815618175]=0.6167, [10480793962]=0.4833, [10479335397]=0.7333, [10480796021]=0.4833, [10469493270]=0.4333, [10469630950]=0.4133, [10469639222]=0.4933, [10503381238]=1.0000, [125750702]=0.6250, [10470104242]=0.7167, [180436148]=0.6500, [10491993682]=1.0250, [15957376722]=1.9167, [12272894215]=0.7167, [13532562418]=0.5333, [13532600125]=0.4556, [13532604085]=0.6778, [13294471966]=0.9111, [12342141464]=5.4444, [12460977270]=1.9444, [12463072679]=0.8889, [14057231976]=1.9111, [13630786846]=1.2333, [15957374019]=1.8333, [13491635433]=0.4556, [13296577783]=0.5556, [13295919399]=0.6778, [13295936866]=0.9444, [12534735382]=2.3333, [12502664044]=1.7778, [12509505723]=1.0556, [12618271998]=1.3778, [12618292188]=0.2556, [12684390285]=2.5000, [12684185971]=0.5333, [12772543293]=4.4333, [14721837245]=3.3333, [12832505612]=2.4333, [13083332742]=2.2667, [13146710762]=2.1889, [180436334]=0.4583, [13370310513]=0.4754, [13390230973]=0.5697, [13378751717]=0.5451, [13378708199]=0.3770, [13377153603]=0.7008, [13376869471]=1.1762, [13294790250]=1.2333, [13376962659]=0.5410, [13365849295]=0.9303, [13501296372]=0.9111, [13556985475]=0.6230, [13379404053]=0.6148, [13499771836]=2.2008, [13497875049]=2.1000, [13632347366]=1.7667, [13643152947]=3.2172, [13634395775]=0.4000, [13639700348]=1.4180, [13723174078]=1.5123, [13881335713]=1.3484, [13876406148]=1.9057, [13380255751]=0.8197, [15957371124]=1.8333, [14357943487]=0.4000, [13997092940]=0.5200, [14001963401]=0.8533, [14357841394]=0.8133, [14136436157]=0.6400, [14358000392]=1.4000, [14357997687]=0.8933, [13379003796]=1.0000, [14358002256]=1.0800, [14004235777]=1.8533, [14003607057]=1.3733, [14046756619]=3.0533, [14048349132]=0.2800, [14299135500]=1.6667, [14967219354]=0.2933, [14351441234]=1.8800, [14733282425]=5.4000, [14719290328]=4.6167, [14701242661]=11.4667, [14900168720]=2.5200, [15128849047]=2.0933, [15134211820]=1.3867, [15983615423]=3.7667, [15146348738]=0.6148, [15271263467]=1.8000, [15259161390]=0.5733, [15240216931]=0.5902, [15240176873]=0.6270, [15162694192]=0.6803, [15290930205]=2.0000, [15145462680]=2.5667, [15295895753]=1.8556, [15295336270]=1.3333, [15311685628]=1.0500, [15391323441]=7.7667, [15520132233]=7.6889, [15676072469]=2.2556, [16062410809]=2.2167, [16082123712]=4.3111, [16136144568]=1.4833, [16515503507]=0.5000, [16515520431]=0.5000, [16515448089]=0.5667, [16552234590]=0.5667, [16139108718]=1.8167, [16139402582]=0.4000, [16515850153]=1.0167, [16431491215]=1.3167, [16597322398]=1.2000, [16597912086]=1.2333, [16734584478]=6.5167, [16737255386]=5.0500, [17464644182]=4.1111, [17450393107]=0.6667, [17275150809]=1.2556, [17275795209]=0.6667, [17860467628]=3.3833, [18435303746]=4.8833, [17889458563]=0.4667, [17889461810]=0.4333, [17889471098]=0.6667, [17889290569]=0.4167, [17799224866]=2.6556, [17838006839]=1.3889, [17838619895]=1.4556, [18179181663]=1.1200, [18435535291]=0.7500, [18435383478]=1.7167, [129651400898906]=1.1833, [18897119503]=1.9000, [106755459092436]=1.5333, [132259592388175]=0.8000, [95575238948327]=0.4667, [102814369422840]=0.7833, [119169968232874]=2.3000, [113166426814229]=0.8500, [116753755471636]=1.7667, [116153572280464]=0.4000, [114095570398448]=0.5667, [138932866508108]=1.7667, [77509627104305]=4.0000, [98542310119798]=3.3333, [91353107056596]=1.0833, [71852503410610]=0.5667, [96558273957850]=1.5000, [140620736290884]=2.0000, [99938926876557]=0.8667, [105616370132258]=9.9833, [123005629431309]=0.4333, [100059874351664]=0.4167, [104895379416342]=0.5000, [134775406437626]=0.5000, [71448437747168]=2.8333, [101588604872680]=1.5333, [102989537449083]=0.7333, [72533960079559]=0.4667, [105442749844047]=1.5000, [131820095363270]=2.4167, [109617620932970]=1.2500, [135289891173395]=1.1667, [125955606488863]=1.1333, [97401167464229]=10.7500, [85025226664507]=2.0500, [84363696088617]=4.0167, [71317401437256]=1.6833, [107484339495811]=3.1667, [136465810903839]=3.8000},
    OwnHealthConnection = nil,
    OwnSource = nil,
    LastOwnHealth = nil,
    FocusName = nil,
    -- R2
    M1MinOverride = nil,
    LastOwnMove = nil,
    M3Health = nil,
    M3ObservedAt = 0,
    M3Id = nil,
    FinishPlan = nil,
    -- R6
    AutoSession = false,
    SelfResetting = false,
    Rejoining = false,
    DiedConnection = nil,
    CommsPeers = {},
    SelfDefense = nil,
    TargetRagdollSince = nil,
    Starting = false,
    DeathHandled = false,
    NextCommsAt = 0,
    Moves = {
        [1] = {name = "FW", key = Enum.KeyCode.One, seed = 17, cooldown = 17, readyAt = 0,
            ids = {[12272894215] = true, [12460977270] = true}}, -- Flowing Water (block breaker)
        [2] = {name = "LWS", key = Enum.KeyCode.Two, seed = 20, cooldown = 20, readyAt = 0,
            ids = {}}, -- Lethal Whirlwind Stream (blockable; learned on first use)
        [3] = {name = "HG", key = Enum.KeyCode.Three, seed = 15, cooldown = 15, readyAt = 0,
            ids = {}}, -- Hunter's Grasp (ragdoll pickup; learned on first use)
    },
    -- idle / walk / loading / unknown tracks never count as a move confirmation
    IgnoreIds = {[119169968232874]=true,[125750702]=true,[12618271998]=true,[13377153603]=true,[13634395775]=true,[13643152947]=true,[138932866508108]=true,[14357841394]=true,[14357943487]=true,[14357997687]=true,[14358000392]=true,[14358002256]=true,[14516273501]=true,[15146348738]=true,[15271263467]=true,[15957371124]=true,[15957374019]=true,[15957376722]=true,[15983615423]=true,[16136144568]=true,[16139402582]=true,[16597322398]=true,[17275795209]=true,[180436148]=true,[180436334]=true,[18435303746]=true,[71448437747168]=true,[72533960079559]=true,[7807831448]=true,[7815618175]=true, [10470389827]=true},
}
local RF = {}

-- ===================== MOBILE: layout + input mapping =====================
-- Default = the calibration you sent (1180x820); the workspace file wins.
RS.MobileYOffsetPx = 0 -- positive moves touchpoints up; negative moves them down
RS.MobileLayout = {
    Move1 = {fx = 0.4144, fy = 0.8890, mode = "CLICK"},
    Move2 = {fx = 0.4737, fy = 0.8927, mode = "CLICK"},
    Move3 = {fx = 0.5297, fy = 0.8927, mode = "CLICK"},
    Move4 = {fx = 0.5856, fy = 0.8927, mode = "CLICK"},
    Block = {fx = 0.9161, fy = 0.2963, mode = "HOLD"},
    Dash = {fx = 0.9025, fy = 0.6049, mode = "CLICK"},
    Attack = {fx = 0.9110, fy = 0.4683, mode = "CLICK"},
    Jump = {fx = 0.9051, fy = 0.7524, mode = "CLICK"},
}
RS.MobileKeyButton = {
    [Enum.KeyCode.Q] = "Dash", [Enum.KeyCode.F] = "Block", [Enum.KeyCode.Space] = "Jump",
    [Enum.KeyCode.One] = "Move1", [Enum.KeyCode.Two] = "Move2",
    [Enum.KeyCode.Three] = "Move3", [Enum.KeyCode.Four] = "Move4",
}
RS.MobileHoldKeys = {[Enum.KeyCode.F] = true, [Enum.KeyCode.Space] = true} -- press-and-hold
RS.MobileTouchId = {Block = 4, Jump = 5, Dash = 6, Move1 = 7, Move2 = 7, Move3 = 7, Move4 = 7}
RS.MobileHeld = {}
RS.MoveVector = Vector3.zero
RS.VirtualKeys = {}
RS.MoveInProgress = false

function RF.loadMobileLayout()
    if type(readfile) ~= "function" then return false end
    local ok, raw = pcall(readfile, CONFIG.MobileLayoutFile)
    if not ok or type(raw) ~= "string" or #raw == 0 then return false end
    local okJ, layout = pcall(function() return game:GetService("HttpService"):JSONDecode(raw) end)
    if not okJ or type(layout) ~= "table" or type(layout.buttons) ~= "table" then return false end
    local savedOffset = tonumber(layout.yOffsetPx)
    if savedOffset and savedOffset == savedOffset and math.abs(savedOffset) <= 10000 then
        RS.MobileYOffsetPx = savedOffset
    end
    for name, b in pairs(layout.buttons) do
        if type(b) == "table" and tonumber(b.fx) and tonumber(b.fy) then
            RS.MobileLayout[name] = {fx = tonumber(b.fx), fy = tonumber(b.fy), mode = b.mode or "CLICK",
                method = b.method or "AUTO"}
        end
    end
    return true
end
RF.loadMobileLayout()

function RF.saveMobileLayout()
    if type(writefile) ~= "function" then return false, "file writing unavailable" end
    local layout = {
        version = 2,
        yOffsetPx = tonumber(RS.MobileYOffsetPx) or 0,
        buttons = {},
    }
    for name, b in pairs(RS.MobileLayout) do
        layout.buttons[name] = {
            fx = tonumber(b.fx),
            fy = tonumber(b.fy),
            mode = b.mode or "CLICK",
            method = b.method or "AUTO",
        }
    end
    local okEncode, raw = pcall(function()
        return game:GetService("HttpService"):JSONEncode(layout)
    end)
    if not okEncode then return false, tostring(raw) end
    local okWrite, writeError = pcall(writefile, CONFIG.MobileLayoutFile, raw)
    if not okWrite then return false, tostring(writeError) end
    return true
end

function RF.mobilePoint(name)
    local b = RS.MobileLayout[name]
    local camera = workspace.CurrentCamera
    local size = camera and camera.ViewportSize or Vector2.new(1180, 820)
    return Vector2.new(math.floor(b.fx * size.X), math.floor(b.fy * size.Y - (RS.MobileYOffsetPx or 0)))
end

-- ===================== MOBILE M3: real mobile input type =====================
-- 1) Input-type spoof: game scripts read UserInputService as a touch device
--    (TouchEnabled true, no mouse/keyboard, last input Touch). Our own calls
--    (checkcaller) see the real values. Installed once per session; a shared
--    flag turns it on/off so re-executing never stacks hooks.
function RF.installTouchSpoof()
    local env = getgenv and getgenv() or _G
    env.TSB_AI_TOUCH_SPOOF = env.TSB_AI_TOUCH_SPOOF or {active = false, installed = false}
    local shared = env.TSB_AI_TOUCH_SPOOF
    RS.Spoof = shared
    if not CONFIG.SpoofTouchInput then shared.active = false return false end
    if shared.installed then shared.active = true return true end
    if type(hookmetamethod) ~= "function" or type(checkcaller) ~= "function"
        or type(getnamecallmethod) ~= "function" then
        return false
    end
    local UIS = UserInputService
    local touchType = Enum.UserInputType.Touch
    local preferredTouch
    pcall(function() preferredTouch = Enum.PreferredInput.Touch end)
    local ok = pcall(function()
        local oldIndex
        oldIndex = hookmetamethod(game, "__index", function(self, key)
            if shared.active and self == UIS and not checkcaller() then
                if key == "TouchEnabled" then return true end
                if key == "MouseEnabled" or key == "KeyboardEnabled" or key == "GamepadEnabled" then
                    return false
                end
                if key == "LastInputType" then return touchType end
                if key == "PreferredInput" and preferredTouch then return preferredTouch end
            end
            return oldIndex(self, key)
        end)
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            if shared.active and self == UIS and not checkcaller()
                and getnamecallmethod() == "GetLastInputType" then
                return touchType
            end
            return oldNamecall(self, ...)
        end)
    end)
    shared.installed = ok
    shared.active = ok
    return ok
end

function RF.spoofActive()
    return RS.Spoof ~= nil and RS.Spoof.installed and RS.Spoof.active
end

-- 2) Direct button presses: find the game's button under the calibrated
--    point and fire its own handlers (no pointer, so any number of buttons
--    can be "held" at once). Falls back to a touch event only if that fails.
RS.ButtonCache = {}
RS.ButtonKind = {}

function RF.connectionsOf(signal)
    if type(getconnections) ~= "function" then return {} end
    local ok, list = pcall(getconnections, signal)
    return ok and type(list) == "table" and list or {}
end

function RF.fireSignal(signal, ...)
    local fired = false
    for _, connection in ipairs(RF.connectionsOf(signal)) do
        local fn = connection.Function
        if type(fn) == "function" then
            task.spawn(fn, ...)
            fired = true
        elseif connection.Fire then
            if pcall(connection.Fire, connection, ...) then fired = true end
        end
    end
    return fired
end

function RF.isOurGui(obj)
    local screen = obj:FindFirstAncestorOfClass("ScreenGui")
    return screen ~= nil and (screen == RS.OurGui or screen.Name == "TSB_AI_Calibrator")
end

function RF.resolveButton(name)
    local cached = RS.ButtonCache[name]
    if cached and cached.Parent and cached:IsDescendantOf(game) and cached.Visible then
        return cached
    end
    RS.ButtonCache[name] = nil
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then return nil end
    local p = RF.mobilePoint(name)
    local inset = game:GetService("GuiService"):GetGuiInset()
    local ok, list = pcall(function()
        return playerGui:GetGuiObjectsAtPosition(p.X - inset.X, p.Y - inset.Y)
    end)
    if not ok or type(list) ~= "table" then return nil end
    -- M4: walk down through every layer at the point; skip containers that
    -- have no handlers (e.g. the full-screen Hotbar.Backpack frame) and take
    -- the first object that actually listens for presses.
    for _, obj in ipairs(list) do
        if not RF.isOurGui(obj) then
            local kind = RF.buttonKindOf(obj)
            if kind then
                RS.ButtonCache[name] = obj
                RS.ButtonKind[name] = kind
                return obj
            end
        end
    end
    return nil
end

function RF.buttonKindOf(obj)
    if #RF.connectionsOf(obj.InputBegan) > 0 then return "INPUT" end
    if obj:IsA("GuiButton") then
        if #RF.connectionsOf(obj.MouseButton1Down) > 0 then return "MB1" end
        if #RF.connectionsOf(obj.Activated) > 0 then return "ACTIVATED" end
        if #RF.connectionsOf(obj.MouseButton1Click) > 0 then return "CLICK" end
    end
    if #RF.connectionsOf(obj.TouchTap) > 0 then return "TOUCHTAP" end
    return nil
end

function RF.fakeTouch(state, p)
    return {
        UserInputType = Enum.UserInputType.Touch,
        UserInputState = state,
        KeyCode = Enum.KeyCode.Unknown,
        Position = Vector3.new(p.X, p.Y, 0),
        Delta = Vector3.zero,
    }
end

-- Fires ONE handler family per button (whichever the game actually uses),
-- so a press never triggers twice.
function RF.directPress(name, state)
    if not CONFIG.DirectButtons or type(getconnections) ~= "function" then return false end
    local obj = RF.resolveButton(name)
    if not obj then return false end
    local p = RF.mobilePoint(name)
    local begin = state == Enum.UserInputState.Begin
    local kind = RS.ButtonKind[name] or RF.buttonKindOf(obj)
    if not kind then return false end
    RS.ButtonKind[name] = kind
    if kind == "INPUT" then
        return RF.fireSignal(begin and obj.InputBegan or obj.InputEnded, RF.fakeTouch(state, p), false)
    elseif kind == "MB1" then
        return RF.fireSignal(begin and obj.MouseButton1Down or obj.MouseButton1Up, p.X, p.Y)
    elseif kind == "ACTIVATED" then
        return begin and RF.fireSignal(obj.Activated, RF.fakeTouch(state, p), 1) or true
    elseif kind == "TOUCHTAP" then
        return begin and RF.fireSignal(obj.TouchTap, {Vector2.new(p.X, p.Y)}, false) or true
    else
        return begin and RF.fireSignal(obj.MouseButton1Click) or true
    end
end

-- ===== PRESSER (shared by the calibrator and the mobile AI) =====
-- Presses a mobile button WITHOUT moving the pointer. Methods:
--   OBJECT : fire the handlers of the game object under / nearest the point
--   GLOBAL : fire the game's own UserInputService InputBegan/TouchStarted
--            listeners with a fake touch at the point (custom touch buttons)
--   TOUCH  : VirtualInputManager touch event (moves the pointer; last resort)
--   AUTO   : OBJECT if a pressable object is found, else GLOBAL
function RF.newPresser(isOurs)
    local P = {}
    local UIS = game:GetService("UserInputService")
    local GuiService = game:GetService("GuiService")
    local VIM = game:GetService("VirtualInputManager")
    local LocalPlayer = game:GetService("Players").LocalPlayer
    local state = {} -- name -> {fake, obj, kind, method}
    P.scanCache = nil

    local function conns(signal)
        if type(getconnections) ~= "function" then return {} end
        local ok, list = pcall(getconnections, signal)
        return ok and type(list) == "table" and list or {}
    end
    P.conns = conns

    local function luaCount(signal)
        local n = 0
        for _, c in ipairs(conns(signal)) do
            if type(c.Function) == "function" then n += 1 end
        end
        return n
    end
    P.luaCount = luaCount

    local function fire(signal, luaOnly, ...)
        local fired = false
        for _, c in ipairs(conns(signal)) do
            if type(c.Function) == "function" then
                task.spawn(c.Function, ...)
                fired = true
            elseif not luaOnly and c.Fire then
                if pcall(c.Fire, c, ...) then fired = true end
            end
        end
        return fired
    end

    local function kindOf(obj)
        if #conns(obj.InputBegan) > 0 then return "INPUT" end
        if obj:IsA("GuiButton") then
            if #conns(obj.MouseButton1Down) > 0 then return "MB1" end
            if #conns(obj.Activated) > 0 then return "ACTIVATED" end
            if #conns(obj.MouseButton1Click) > 0 then return "CLICK" end
        end
        if #conns(obj.TouchTap) > 0 then return "TOUCHTAP" end
        return nil
    end
    P.kindOf = kindOf

    local function shown(obj)
        local o = obj
        while o and o:IsA("GuiObject") do
            if not o.Visible then return false end
            o = o.Parent
        end
        local screen = obj:FindFirstAncestorOfClass("ScreenGui")
        return not screen or screen.Enabled
    end

    function P.guiPoint(p)
        local inset = GuiService:GetGuiInset()
        return Vector2.new(p.X - inset.X, p.Y - inset.Y)
    end

    function P.layersAt(p)
        local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local g = P.guiPoint(p)
        local ok, list = pcall(function() return playerGui:GetGuiObjectsAtPosition(g.X, g.Y) end)
        local out = {}
        if ok and type(list) == "table" then
            for _, obj in ipairs(list) do
                if not isOurs(obj) then table.insert(out, obj) end
            end
        end
        return out
    end

    -- every visible handler-bearing object in PlayerGui (cached until reset)
    function P.scan()
        if P.scanCache then return P.scanCache end
        local list = {}
        local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if playerGui then
            for _, obj in ipairs(playerGui:GetDescendants()) do
                if obj:IsA("GuiObject") and not isOurs(obj) and obj.AbsoluteSize.X > 0 then
                    local kind = kindOf(obj)
                    if kind then table.insert(list, {obj = obj, kind = kind}) end
                end
            end
        end
        P.scanCache = list
        return list
    end

    function P.resetCache()
        P.scanCache = nil
        for _, s in pairs(state) do s.obj = nil end
    end

    -- object under the point, else the nearest pressable object within 70 px
    function P.findObject(p)
        for _, obj in ipairs(P.layersAt(p)) do
            local kind = kindOf(obj)
            if kind then return obj, kind, "layer" end
        end
        local g = P.guiPoint(p)
        local best, bestKind, bestScore
        for _, entry in ipairs(P.scan()) do
            local obj = entry.obj
            if obj.Parent and shown(obj) then
                local pos, size = obj.AbsolutePosition, obj.AbsoluteSize
                local inside = g.X >= pos.X and g.X <= pos.X + size.X and g.Y >= pos.Y and g.Y <= pos.Y + size.Y
                local center = pos + size / 2
                local d = (center - g).Magnitude
                if inside or d <= 70 then
                    local score = (inside and 0 or 100000) + size.X * size.Y * 0.001 + d
                    if not bestScore or score < bestScore then
                        best, bestKind, bestScore = obj, entry.kind, score
                    end
                end
            end
        end
        if best then return best, bestKind, "nearest" end
        return nil
    end

    local function fakeTouch(p)
        local g = P.guiPoint(p)
        return {
            UserInputType = Enum.UserInputType.Touch,
            UserInputState = Enum.UserInputState.Begin,
            KeyCode = Enum.KeyCode.Unknown,
            Position = Vector3.new(g.X, g.Y, 0),
            Delta = Vector3.zero,
        }
    end

    -- begin a press; returns the method actually used
    function P.begin(name, p, method, touchId)
        method = method or "AUTO"
        local s = {fake = fakeTouch(p), p = p, touchId = touchId}
        state[name] = s
        if method == "AUTO" or method == "OBJECT" then
            local obj, kind = P.findObject(p)
            if obj then
                s.obj, s.kind, s.method = obj, kind, "OBJECT"
                local f = s.fake
                if kind == "INPUT" then fire(obj.InputBegan, false, f, false)
                elseif kind == "MB1" then fire(obj.MouseButton1Down, false, f.Position.X, f.Position.Y)
                elseif kind == "ACTIVATED" then fire(obj.Activated, false, f, 1)
                elseif kind == "CLICK" then fire(obj.MouseButton1Click, false)
                elseif kind == "TOUCHTAP" then fire(obj.TouchTap, false, {Vector2.new(f.Position.X, f.Position.Y)}, false)
                end
                return "OBJECT:" .. kind
            end
            if method == "OBJECT" then s.method = "NONE" return "OBJECT:none" end
        end
        if method == "AUTO" or method == "GLOBAL" then
            s.method = "GLOBAL"
            local a = fire(UIS.InputBegan, true, s.fake, false)
            local b = fire(UIS.TouchStarted, true, s.fake, false)
            return (a or b) and "GLOBAL" or "GLOBAL:none"
        end
        s.method = "TOUCH"
        pcall(function()
            VIM:SendTouchEvent(touchId or 9, Enum.UserInputState.Begin, p.X, p.Y, 0)
        end)
        return "TOUCH"
    end

    function P.finish(name)
        local s = state[name]
        if not s then return end
        state[name] = nil
        s.fake.UserInputState = Enum.UserInputState.End
        if s.method == "OBJECT" and s.obj then
            local obj, f = s.obj, s.fake
            if s.kind == "INPUT" then fire(obj.InputEnded, false, f, false)
            elseif s.kind == "MB1" then fire(obj.MouseButton1Up, false, f.Position.X, f.Position.Y) end
        elseif s.method == "GLOBAL" then
            fire(UIS.InputEnded, true, s.fake, false)
            fire(UIS.TouchEnded, true, s.fake, false)
        elseif s.method == "TOUCH" then
            pcall(function()
                VIM:SendTouchEvent(s.touchId or 9, Enum.UserInputState.End, s.p.X, s.p.Y, 0)
            end)
        end
    end

    function P.held(name) return state[name] ~= nil end
    return P
end

-- M5: every button press goes through the presser, using the per-button
-- method saved by the calibrator (AUTO / OBJECT / GLOBAL / TOUCH).
RF.P = RF.newPresser(function(obj) return RF.isOurGui(obj) end)

function RF.mobileTouch(name, state)
    if state == Enum.UserInputState.Begin then
        if RF.P.held(name) then RF.P.finish(name) end
        local b = RS.MobileLayout[name]
        RS.LastPressMethod = RF.P.begin(name, RF.mobilePoint(name), b and b.method or "AUTO",
            RS.MobileTouchId[name] or 8)
    else
        RF.P.finish(name)
    end
end

local function getCharacterParts()
    Character = LocalPlayer.Character
    if not Character then return false end
    Humanoid = Character:FindFirstChildOfClass("Humanoid")
    Root = Character:FindFirstChild("HumanoidRootPart")
    Animator = Humanoid and Humanoid:FindFirstChildOfClass("Animator")
    return Humanoid and Root and Animator and Humanoid.Health > 0
end

local function animationId(track)
    if not track or not track.Animation then return nil end
    return tonumber(track.Animation.AnimationId:match("%d+"))
end

local function alive(character)
    local h = character and character:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0 and character:FindFirstChild("HumanoidRootPart") ~= nil
end

local function isRagdolled(character)
    local h = character and character:FindFirstChildOfClass("Humanoid")
    if not h or h.Health <= 0 then return false end
    local state = h:GetState()
    local ragdollState = state == Enum.HumanoidStateType.Ragdoll
        or state == Enum.HumanoidStateType.FallingDown
        or state == Enum.HumanoidStateType.Physics
        or state == Enum.HumanoidStateType.PlatformStanding
    return h.PlatformStand == true and ragdollState
end

local function isGettingUpState(character)
    local h = character and character:FindFirstChildOfClass("Humanoid")
    return h and h:GetState() == Enum.HumanoidStateType.GettingUp
end

local function hasGetupIFrames(character)
    return isGettingUpState(character)
        or os.clock() < TargetGetupIFrameUntil
end

local function targetCanReceiveM1(character)
    local h = character and character:FindFirstChildOfClass("Humanoid")
    if not h or h.Health <= 0 or not character:FindFirstChild("HumanoidRootPart") then
        return false
    end
    if h.PlatformStand or isRagdolled(character) or hasGetupIFrames(character) then
        return false
    end
    return true
end

local function flat(vector)
    return Vector3.new(vector.X, 0, vector.Z)
end

local function unitOr(vector, fallback)
    if vector.Magnitude > 0.05 then return vector.Unit end
    return fallback
end

local function distanceTo(character)
    local otherRoot = character and character:FindFirstChild("HumanoidRootPart")
    if not Root or not otherRoot then return math.huge end
    return (flat(otherRoot.Position - Root.Position)).Magnitude
end


-- ===================== R1: friends / team =====================
function RF.nameIn(list, player)
    local dn = string.lower(tostring(player.DisplayName or ""))
    local un = string.lower(tostring(player.Name or ""))
    for _, name in ipairs(list) do
        local l = string.lower(name)
        if dn == l or un == l then return true end
    end
    return false
end

function RF.friendRole(player)
    if not player or not CONFIG.TeamEnabled then return nil end
    if RF.nameIn(CONFIG.TeamProtected, player) then return "PROTECTED" end
    if RF.nameIn(CONFIG.TeamAllies, player) then return "ALLY" end
    return nil
end

function RF.isFriend(player)
    return player ~= nil and RF.friendRole(player) ~= nil
end

function RF.isCoopAlly(player)
    local role = RF.friendRole(player)
    return role == "ALLY" or (role == "PROTECTED" and CONFIG.CoopWithProtected)
end

-- Team behavior runs when the account executing the script is on the roster.
function RF.teamModeActive()
    return CONFIG.TeamEnabled and RF.friendRole(LocalPlayer) ~= nil
end

function RF.rootOf(player)
    local character = player and player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

function RF.facingDot(fromRoot, toPosition)
    local offset = flat(toPosition - fromRoot.Position)
    if offset.Magnitude < 0.05 then return 1 end
    return unitOr(flat(fromRoot.CFrame.LookVector), offset.Unit):Dot(offset.Unit)
end

function RF.aimedAtUs(sourceRoot)
    return Root ~= nil and sourceRoot ~= nil
        and RF.facingDot(sourceRoot, Root.Position) >= CONFIG.FacingDot
end

-- Closing speed only. Strafing past us does not inflate reach.
function RF.dynamicReach(base, sourceRoot)
    if not sourceRoot or not Root then return base end
    local toUs = unitOr(flat(Root.Position - sourceRoot.Position), Vector3.zero)
    local closing = flat(sourceRoot.AssemblyLinearVelocity):Dot(toUs)
        - flat(Root.AssemblyLinearVelocity):Dot(toUs)
    return base + math.clamp(closing * CONFIG.DynamicLeadTime, 0, CONFIG.DynamicBonusMax)
end

function RF.playingAnimation(character, id)
    local h = character and character:FindFirstChildOfClass("Humanoid")
    local animator = h and h:FindFirstChildOfClass("Animator")
    if not animator then return false end
    local ok, tracks = pcall(function() return animator:GetPlayingAnimationTracks() end)
    if not ok or not tracks then return false end
    for _, track in ipairs(tracks) do
        if track.IsPlaying and animationId(track) == id then return true end
    end
    return false
end

function RF.friendRoots(maxDistance)
    local list = {}
    if not Root then return list end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and RF.isFriend(player) and alive(player.Character) then
            local r = player.Character:FindFirstChild("HumanoidRootPart")
            if r and flat(r.Position - Root.Position).Magnitude <= (maxDistance or math.huge) then
                table.insert(list, {player = player, root = r})
            end
        end
    end
    return list
end

function RF.allyNearRoot(sourceRoot, range)
    if not sourceRoot then return false end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and RF.isFriend(player) then
            local r = RF.rootOf(player)
            if r and alive(player.Character)
                and flat(r.Position - sourceRoot.Position).Magnitude <= range then
                return true
            end
        end
    end
    return false
end

function RF.applyFriendSeparation(direction)
    if not Root or direction.Magnitude < 0.05 then return direction end
    local push = Vector3.zero
    for _, f in ipairs(RF.friendRoots(CONFIG.FriendSeparation)) do
        local away = flat(Root.Position - f.root.Position)
        local d = away.Magnitude
        if d > 0.05 then
            push += away.Unit * (1 - d / CONFIG.FriendSeparation)
        end
    end
    if push.Magnitude < 0.05 then return direction end
    return unitOr(direction.Unit + push * 1.2, direction.Unit)
end

-- Never swing when a friend stands between us and the target in the M1 cone.
function RF.friendlyInAttackCone(targetRoot)
    if not Root or not targetRoot then return false end
    local toTarget = flat(targetRoot.Position - Root.Position)
    local targetDistance = toTarget.Magnitude
    if targetDistance < 0.05 then return false end
    local forward = toTarget.Unit
    for _, f in ipairs(RF.friendRoots(CONFIG.M1Range + 2)) do
        local offset = flat(f.root.Position - Root.Position)
        local d = offset.Magnitude
        if d > 0.05 and d <= targetDistance + 1.5
            and offset.Unit:Dot(forward) >= CONFIG.FriendlyFireCone then
            return true
        end
    end
    return false
end

function RF.teamStrafeSign(sign, right)
    if not RF.teamModeActive() or not Root then return sign end
    for _, f in ipairs(RF.friendRoots(8)) do
        local side = flat(f.root.Position - Root.Position):Dot(right)
        if side > 0.5 then return -1 end
        if side < -0.5 then return 1 end
    end
    return sign
end

function RF.strafeFlip(now)
    if not CONFIG.StrafeVariance then return 1 end
    if now >= RS.NextStrafeFlipAt then
        if math.random() < 0.5 then RS.StrafeFlipSign = -RS.StrafeFlipSign end
        RS.NextStrafeFlipAt = now + CONFIG.StrafeFlipMin
            + math.random() * (CONFIG.StrafeFlipMax - CONFIG.StrafeFlipMin)
    end
    return RS.StrafeFlipSign
end

-- Chatless coordination: each ally's intent is read from what their
-- character is doing. Engaged = facing/closing on an enemy. Pressured = an
-- enemy on top of them while they block, ragdoll or lose health. Falling back
-- = running toward us with that enemy following (the help signal this AI also
-- sends when low).
function RF.updateAllyIntent(now)
    if now < RS.NextTeamScan then return end
    RS.NextTeamScan = now + CONFIG.TeamScanInterval
    if not RF.teamModeActive() then
        RS.AllyIntent = {}
        return
    end
    local seen = {}
    local players = Players:GetPlayers()
    for _, ally in ipairs(players) do
        if ally ~= LocalPlayer and RF.isCoopAlly(ally) and alive(ally.Character) then
            local aRoot = RF.rootOf(ally)
            local aHum = ally.Character:FindFirstChildOfClass("Humanoid")
            local intent = RS.AllyIntent[ally] or {lastHealth = aHum.Health, hurtAt = -math.huge}
            if aHum.Health < intent.lastHealth - 0.5 then intent.hurtAt = now end
            intent.lastHealth = aHum.Health
            intent.ragdolled = isRagdolled(ally.Character)
            intent.blocking = RF.playingAnimation(ally.Character, BLOCK_ANIMATION_ID)
            intent.lowHealth = aHum.MaxHealth > 0
                and aHum.Health / aHum.MaxHealth <= CONFIG.LowHealthRatio

            local aVel = flat(aRoot.AssemblyLinearVelocity)
            local engaged, engagedScore, pressuredBy, pressureDist
            for _, enemy in ipairs(players) do
                if enemy ~= LocalPlayer and not RF.isFriend(enemy) and alive(enemy.Character) then
                    local eRoot = RF.rootOf(enemy)
                    local offset = flat(eRoot.Position - aRoot.Position)
                    local d = offset.Magnitude
                    local dir = d > 0.05 and offset.Unit or Vector3.zero
                    if d <= CONFIG.AllyEngageRange then
                        local look = RF.facingDot(aRoot, eRoot.Position)
                        local closing = aVel:Dot(dir)
                        if look > 0.5 or closing > 4 then
                            local score = d - look * 4 - math.max(0, closing) * 0.5
                            if not engagedScore or score < engagedScore then
                                engaged, engagedScore = enemy, score
                            end
                        end
                    end
                    if d <= CONFIG.AllyPressureRange
                        and RF.facingDot(eRoot, aRoot.Position) > 0.5
                        and (not pressureDist or d < pressureDist) then
                        pressuredBy, pressureDist = enemy, d
                    end
                end
            end

            -- R6: a fresh file-comms report beats inference
            local peer = RS.CommsPeers[ally.Name]
            if peer and peer.target ~= "" then
                local told = Players:FindFirstChild(peer.target)
                if told and told ~= LocalPlayer and not RF.isFriend(told) then
                    engaged = told
                end
            end
            intent.engaged = engaged
            local losing = intent.ragdolled or intent.blocking or now - intent.hurtAt < 1.0
            intent.pressuredBy = (pressuredBy and losing) and pressuredBy or nil
            intent.fallingBack = false
            if Root and pressuredBy then
                local toUs = flat(Root.Position - aRoot.Position)
                if toUs.Magnitude > 0.05 and toUs.Magnitude <= CONFIG.FallbackRange
                    and aVel:Dot(toUs.Unit) > 6 then
                    intent.fallingBack = true
                    intent.pressuredBy = pressuredBy
                end
            end
            RS.AllyIntent[ally] = intent
            seen[ally] = true
        end
    end
    for ally in pairs(RS.AllyIntent) do
        if not seen[ally] then RS.AllyIntent[ally] = nil end
    end
end

-- R8 roles by name: the leader fights; every other roster ally escorts.
function RF.isLeaderPlayer(player)
    if not player then return false end
    local l = string.lower(CONFIG.TeamLeader)
    return string.lower(tostring(player.Name)) == l or string.lower(tostring(player.DisplayName)) == l
end

function RF.leaderPlayer()
    for _, player in ipairs(Players:GetPlayers()) do
        if RF.isLeaderPlayer(player) and alive(player.Character) then return player end
    end
    return nil
end

function RF.teamRole()
    if not RF.teamModeActive() or RF.friendRole(LocalPlayer) ~= "ALLY" then return nil end
    if RF.isLeaderPlayer(LocalPlayer) then return "LEADER" end
    local leader = RF.leaderPlayer()
    return leader and "ESCORT" or nil
end

-- Escorts only fight near the leader (or whoever attacks them).
function RF.escortAllows(enemy)
    if RF.teamRole() ~= "ESCORT" or not enemy then return true end
    local defense = RS.SelfDefense
    if defense and defense.player == enemy and os.clock() < defense.untilAt then return true end
    local leaderRoot, enemyRoot = RF.rootOf(RF.leaderPlayer()), RF.rootOf(enemy)
    if not leaderRoot or not enemyRoot then return true end
    return flat(enemyRoot.Position - leaderRoot.Position).Magnitude <= CONFIG.EscortLeash
        or distanceTo(enemy.Character) <= CONFIG.ExternalRetargetRange
end

function RF.nowMs()
    local ok, value = pcall(function() return DateTime.now().UnixTimestampMillis end)
    return ok and value or math.floor(os.time() * 1000)
end

-- R6 file comms: bots on the same PC share their target through the
-- executor workspace. Needs writefile / readfile / listfiles; silently off
-- when the executor lacks them or the bots run on different machines.
function RF.commsTick(now)
    if not CONFIG.FileComms or not RF.teamModeActive() or now < RS.NextCommsAt then return end
    RS.NextCommsAt = now + CONFIG.CommsInterval
    if type(writefile) ~= "function" or type(readfile) ~= "function"
        or type(listfiles) ~= "function" then
        return
    end
    local HttpService = game:GetService("HttpService")
    pcall(function()
        if type(isfolder) == "function" and not isfolder(CONFIG.CommsFolder) then
            makefolder(CONFIG.CommsFolder)
        end
        writefile(CONFIG.CommsFolder .. "/" .. LocalPlayer.Name .. ".json", HttpService:JSONEncode({
            name = LocalPlayer.Name,
            job = game.JobId,
            target = CurrentTarget and CurrentTarget.Name or "",
            role = RF.teamRole() or "",
            state = State,
            t = RF.nowMs(),
        }))
    end)
    local peers = {}
    pcall(function()
        for _, path in ipairs(listfiles(CONFIG.CommsFolder)) do
            if not path:find(LocalPlayer.Name .. ".json", 1, true) then
                local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
                if ok and type(data) == "table" and data.job == game.JobId
                    and RF.nowMs() - (tonumber(data.t) or 0) <= CONFIG.CommsStaleMs then
                    peers[data.name] = data
                end
            end
        end
    end)
    RS.CommsPeers = peers
end

-- The ally currently fighting this enemy (for pincer positioning).
function RF.allyRootEngagedWith(enemy)
    for ally, intent in pairs(RS.AllyIntent) do
        if intent.engaged == enemy or intent.pressuredBy == enemy then
            local r = RF.rootOf(ally)
            if r then return r, ally end
        end
    end
    return nil
end

-- R7 claims: an enemy an ally is already fighting belongs to that ally.
-- Tie (both of us on it): FRONT keeps it over FLANK; two FRONTs -> the
-- alphabetically lower name keeps it. Exceptions: self defense, and rescue
-- when the ally is low and pressured.
-- Tie: the leader always keeps; between escorts the lower name keeps.
function RF.weKeepTie(ally)
    if RF.isLeaderPlayer(LocalPlayer) then return true end
    if RF.isLeaderPlayer(ally) then return false end
    return string.lower(LocalPlayer.Name) < string.lower(ally.Name)
end

function RF.claimedByAlly(enemy)
    if not CONFIG.OneOnOne or not enemy or not RF.teamModeActive() then return false end
    local defense = RS.SelfDefense
    if defense and defense.player == enemy and os.clock() < defense.untilAt then return false end
    local weAreOnIt = CurrentTarget == enemy and distanceTo(enemy.Character) <= CONFIG.AllyEngageRange
    for ally, intent in pairs(RS.AllyIntent) do
        if intent.engaged == enemy then
            local rescue = CONFIG.GuardRescueLowHealth and intent.lowHealth
                and intent.pressuredBy == enemy
            if not rescue and not (weAreOnIt and RF.weKeepTie(ally)) then
                return true, ally
            end
        end
    end
    return false
end

-- Lower is better. Plain distance outside team mode (MK.1 behavior).
function RF.targetScore(player)
    local score = distanceTo(player.Character)
    if not RF.teamModeActive() then return score end
    local eRoot = RF.rootOf(player)
    for ally, intent in pairs(RS.AllyIntent) do
        if intent.pressuredBy == player and intent.lowHealth then
            score -= CONFIG.RescueBonus
        end
        -- an unclaimed enemy closing on an ally's back comes first
        local aRoot = RF.rootOf(ally)
        if eRoot and aRoot and intent.engaged ~= player
            and flat(eRoot.Position - aRoot.Position).Magnitude <= CONFIG.ThreatToAllyRange then
            score -= CONFIG.ThreatToAllyBonus
        end
    end
    return score
end

-- Outgoing help signal: when low, fall back toward the nearest ally so the
-- chaser is dragged into them.
function RF.fallbackBias(awayDirection)
    if not RF.teamModeActive() or not Humanoid or not Root then return awayDirection end
    if Humanoid.MaxHealth <= 0
        or Humanoid.Health / Humanoid.MaxHealth > CONFIG.LowHealthRatio then
        return awayDirection
    end
    local best, bestDistance
    for _, ally in ipairs(Players:GetPlayers()) do
        if ally ~= LocalPlayer and RF.isCoopAlly(ally) and alive(ally.Character) then
            local r = RF.rootOf(ally)
            local d = r and flat(r.Position - Root.Position).Magnitude
            if d and d <= CONFIG.FallbackRange and (not bestDistance or d < bestDistance) then
                best, bestDistance = r, d
            end
        end
    end
    if not best or bestDistance < 6 then return awayDirection end
    local toAlly = flat(best.Position - Root.Position).Unit
    return unitOr(awayDirection + toAlly * 1.1, awayDirection)
end

local function validTarget(player)
    if not player or player == LocalPlayer then return false end
    if RF.isFriend(player) then return false end
    return alive(player.Character) and distanceTo(player.Character) <= CONFIG.TargetRange
end

local function chooseTarget()
    local candidates = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if validTarget(player) and not RF.claimedByAlly(player) and RF.escortAllows(player) then
            table.insert(candidates, player)
        end
    end
    if #candidates == 0 then return nil end
    if CONFIG.TargetMode == "Random" then
        return candidates[math.random(1, #candidates)]
    end
    table.sort(candidates, function(a, b)
        return RF.targetScore(a) < RF.targetScore(b)
    end)
    return candidates[1]
end

local function turnCamera(direction, blendOverride)
    local camera = workspace.CurrentCamera
    if not camera or direction.Magnitude < 0.05 then return end
    local desired = flat(direction).Unit
    local current = camera.CFrame.LookVector
    local currentFlat = flat(current)
    if currentFlat.Magnitude > 0.05
        and currentFlat.Unit:Dot(desired) >= math.cos(CONFIG.CameraTurnDeadzone) then
        return
    end
    local blend = math.clamp(blendOverride or CONFIG.CameraTurnRate, 0, 1)
    local blended = unitOr(flat(current) * (1 - blend) + desired * blend, desired)
    local height = math.clamp(current.Y, -0.25, 0.25)
    local look = unitOr(Vector3.new(blended.X, height, blended.Z), desired)
    camera.CFrame = CFrame.lookAt(camera.CFrame.Position, camera.CFrame.Position + look)
end

local function faceTarget(targetRoot, instant)
    if not Root or not targetRoot then return end
    turnCamera(targetRoot.Position - Root.Position, instant and 1 or nil)
end

local function sendKey(key, down)
    -- MOBILE M2: W/A/S/D are kept as a virtual key state and fed to
    -- Humanoid:Move exactly like the keyboard control module would
    -- (camera-relative, same 8 directions, same hysteresis upstream).
    if key == Enum.KeyCode.W or key == Enum.KeyCode.A or key == Enum.KeyCode.S
        or key == Enum.KeyCode.D then
        RS.VirtualKeys[key] = down or nil
        return
    end
    if key == Enum.KeyCode.LeftShift then return end -- shift lock is emulated
    local name = RS.MobileKeyButton[key]
    if not name then
        pcall(function() VirtualInputManager:SendKeyEvent(down, key, false, game) end)
        return
    end
    if RS.MobileHoldKeys[key] or RS.MobileLayout[name].mode == "HOLD" then
        if down and not RS.MobileHeld[name] then
            RS.MobileHeld[name] = true
            RF.mobileTouch(name, Enum.UserInputState.Begin)
        elseif not down and RS.MobileHeld[name] then
            RS.MobileHeld[name] = nil
            RF.mobileTouch(name, Enum.UserInputState.End)
        end
    elseif down then
        task.spawn(function()
            RF.mobileTouch(name, Enum.UserInputState.Begin)
            task.wait()
            RF.mobileTouch(name, Enum.UserInputState.End)
        end)
    end
end

local HeldMoveKeys = {}

local function setMoveKey(key, shouldHold)
    if HeldMoveKeys[key] == shouldHold then return end
    HeldMoveKeys[key] = shouldHold
    sendKey(key, shouldHold)
end

local function releaseMoveKeys()
    setMoveKey(Enum.KeyCode.W, false)
    setMoveKey(Enum.KeyCode.A, false)
    setMoveKey(Enum.KeyCode.S, false)
    setMoveKey(Enum.KeyCode.D, false)
end

local function movementDirection(worldDirection, mode)
    if not Humanoid then return end
    local direction = flat(worldDirection)
    if direction.Magnitude < 0.05 then
        releaseMoveKeys()
        LastMoveDirection = nil
        LastMoveForward = nil
        LastMoveRight = nil
        LastMoveMode = nil
        LastMoveKeyReassertAt = 0
        return
    end

    local camera = workspace.CurrentCamera
    local forward = camera and flat(camera.CFrame.LookVector) or flat(Root.CFrame.LookVector)
    local right = camera and flat(camera.CFrame.RightVector) or flat(Root.CFrame.RightVector)
    forward = unitOr(forward, Vector3.new(0, 0, -1))
    right = unitOr(right, Vector3.new(1, 0, 0))

    local desired = direction.Unit
    local moveMode = mode or "DEFAULT"
    local recomputeKeys = not LastMoveDirection
        or desired:Dot(LastMoveDirection) < CONFIG.MovementDirectionHysteresis
        or not LastMoveForward
        or forward:Dot(LastMoveForward) < CONFIG.MovementCameraHysteresis
        or not LastMoveRight
        or right:Dot(LastMoveRight) < CONFIG.MovementCameraHysteresis
        or moveMode ~= LastMoveMode

    if recomputeKeys then
        local forwardAmount = desired:Dot(forward)
        local rightAmount = desired:Dot(right)
        setMoveKey(Enum.KeyCode.W, forwardAmount > 0.25)
        setMoveKey(Enum.KeyCode.S, forwardAmount < -0.25)
        setMoveKey(Enum.KeyCode.D, rightAmount > 0.25)
        setMoveKey(Enum.KeyCode.A, rightAmount < -0.25)
        LastMoveDirection = desired
        LastMoveForward = forward
        LastMoveRight = right
        LastMoveMode = moveMode
    end

    local now = os.clock()
    if now - LastMoveKeyReassertAt >= CONFIG.MoveKeyReassertInterval then
        if HeldMoveKeys[Enum.KeyCode.W] then sendKey(Enum.KeyCode.W, true) end
        if HeldMoveKeys[Enum.KeyCode.A] then sendKey(Enum.KeyCode.A, true) end
        if HeldMoveKeys[Enum.KeyCode.S] then sendKey(Enum.KeyCode.S, true) end
        if HeldMoveKeys[Enum.KeyCode.D] then sendKey(Enum.KeyCode.D, true) end
        LastMoveKeyReassertAt = now
    end

    -- Keyboard holds are the movement authority. Do not also call
    -- Humanoid:Move every Heartbeat; competing client movement vectors make
    -- the replicated character look stuttery and can fight dodge movement.
end

local function combatMovementDirection(targetRoot, mode)
    if not Root or not targetRoot then return Vector3.zero end

    local targetToUs = flat(Root.Position - targetRoot.Position)
    local distance = targetToUs.Magnitude
    local away = unitOr(targetToUs, -flat(targetRoot.CFrame.LookVector))
    local camera = workspace.CurrentCamera
    local right = camera and flat(camera.CFrame.RightVector)
        or flat(targetRoot.CFrame.RightVector)
    right = unitOr(right, Vector3.new(1, 0, 0))

    local sideSign = targetToUs:Dot(right) >= 0 and 1 or -1
    local targetSideSpeed = flat(targetRoot.AssemblyLinearVelocity):Dot(right)
    if math.abs(targetSideSpeed) > 2 then
        sideSign = targetSideSpeed > 0 and -1 or 1
    elseif mode ~= "BLOCK" then
        sideSign *= RF.strafeFlip(os.clock())
    end
    sideSign = RF.teamStrafeSign(sideSign, right)
    local side = right * sideSign

    local radial = Vector3.zero
    if distance < CONFIG.M1MinRange + 0.20 then
        radial = away * 0.90
    elseif distance > CONFIG.M1Range - 0.45 then
        radial = -away * 0.30
    end

    if mode == "BLOCK" or mode == "RECOVERY" then
        if distance < CONFIG.M1MinRange + 0.55 then
            radial = away
        end
        return RF.applyFriendSeparation(unitOr(side * 0.90 + radial * 0.65, side))
    end

    return RF.applyFriendSeparation(unitOr(side * 0.90 + radial, side))
end

local function stopAttackInputs()
    sendKey(Enum.KeyCode.Q, false)
    sendKey(Enum.KeyCode.Space, false)
end

local function releaseAutoBlock()
    if not IsBlocking then return end
    sendKey(Enum.KeyCode.F, false)
    IsBlocking = false
    BlockTrack = nil
    BlockId = nil
    BlockKind = nil
    BlockStartedAt = 0
    BlockExpectedEnd = 0
end

local function stopAllInputs()
    sendKey(Enum.KeyCode.Q, false)
    sendKey(Enum.KeyCode.Space, false)
    releaseAutoBlock()
    releaseMoveKeys()
    LastMoveDirection = nil
    LastMoveForward = nil
    LastMoveRight = nil
    LastMoveMode = nil
    LastMoveKeyReassertAt = 0
end

local function invalidateAction()
    ActionGeneration += 1
    return ActionGeneration
end

local function actionStillValid(token, target)
    if not CONFIG.Enabled then return false end
    if token and token ~= ActionGeneration then return false end
    if target then
        if CurrentTarget ~= target or not validTarget(target) then return false end
        if not target.Character or not alive(target.Character) then return false end
    end
    if PendingReaction then return false end
    return true
end

local function waitInterruptible(duration, token, target)
    local started = os.clock()
    while os.clock() - started < duration do
        if not actionStillValid(token, target) then return false end
        RunService.Heartbeat:Wait()
    end
    return actionStillValid(token, target)
end

local function attackTap()
    local camera = workspace.CurrentCamera
    if not camera then return false end
    local point = RF.mobilePoint("Attack") -- MOBILE: calibrated attack button
    local x = math.floor(point.X)
    local y = math.floor(point.Y)

    do -- M5: presser (no pointer unless the Attack method is TOUCH)
        RF.mobileTouch("Attack", Enum.UserInputState.Begin)
        task.wait()
        RF.mobileTouch("Attack", Enum.UserInputState.End)
        return true
    end

    local tap = _G.touchTap or _G.touch_tap or _G.tap or touchTap or touch_tap
    if type(tap) == "function" then
        local ok = pcall(tap, x, y)
        if ok then return true end
    end

    local touchWorked = pcall(function()
        VirtualInputManager:SendTouchEvent(0, Enum.UserInputState.Begin, x, y, 0)
        task.wait()
        VirtualInputManager:SendTouchEvent(0, Enum.UserInputState.End, x, y, 0)
    end)
    if touchWorked then
        return true
    end

    local ok = pcall(function()
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait()
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
    return ok
end

local function classifyDashDirection(worldDirection)
    local camera = workspace.CurrentCamera
    local forward = camera and flat(camera.CFrame.LookVector) or flat(Root.CFrame.LookVector)
    local right = camera and flat(camera.CFrame.RightVector) or flat(Root.CFrame.RightVector)
    forward = unitOr(forward, flat(Root.CFrame.LookVector).Unit)
    right = unitOr(right, Vector3.new(1, 0, 0))
    local direction = flat(worldDirection).Unit
    local forwardAmount = direction:Dot(forward)
    local rightAmount = direction:Dot(right)
    if forwardAmount > 0.55 then return "FRONT" end
    if forwardAmount < -0.55 then return "BACK" end
    if rightAmount < 0 then return "LEFT" end
    return "RIGHT"
end

local function dashCooldownReady(kind)
    if kind == "LEFT" or kind == "RIGHT" then
        return os.clock() - LastSideDash >= CONFIG.SideDashCooldown
    end
    return os.clock() - LastFrontBackDash >= CONFIG.FrontBackDashCooldown
end

local function waitForDashEnd(previousSerial, token)
    local started = os.clock()
    local sawDashTrack = false

    while CONFIG.Enabled and os.clock() - started < CONFIG.DashStartTimeout do
        if token and token ~= ActionGeneration then return false end
        if OwnDashSerial > previousSerial then
            sawDashTrack = true
            break
        end
        RunService.Heartbeat:Wait()
    end

    if not sawDashTrack then
        ActiveDashTrack = nil
        return false
    end

    local track = ActiveDashTrack
    while CONFIG.Enabled and os.clock() - started < CONFIG.DashTimeout do
        if token and token ~= ActionGeneration then return false end
        if not track or not track.IsPlaying then
            ActiveDashTrack = nil
            return true
        end
        RunService.Heartbeat:Wait()
    end

    ActiveDashTrack = nil
    return false
end

local function dashEndedInContact(targetRoot)
    if not targetRoot or not Root then return false end
    local liveRoot = targetRoot
    if targetRoot.Parent then
        liveRoot = targetRoot.Parent:FindFirstChild("HumanoidRootPart") or targetRoot
    end
    if not liveRoot or not liveRoot.Parent then return false end
    return (liveRoot.Position - Root.Position).Magnitude <= CONFIG.DashContactRange
end

local function performDash(worldDirection, token, targetRoot, requireContact)
    if not Root or not Humanoid then return false end
    if token and not actionStillValid(token) then return false end
    local direction = unitOr(flat(worldDirection), flat(Root.CFrame.LookVector).Unit)
    local kind = classifyDashDirection(direction)
    if not dashCooldownReady(kind) then return false end
    local wasOwnRagdolled = isRagdolled(Character)

    movementDirection(direction, "DASH_ALIGN")
    if not waitInterruptible(0.035, token) then
        stopAllInputs()
        return false
    end
    local previousSerial = OwnDashSerial
    ActiveDashTrack = nil
    ActiveOwnDashKind = kind
    sendKey(Enum.KeyCode.Q, true)
    task.wait()
    sendKey(Enum.KeyCode.Q, false)

    State = "DASH_ACTIVE_" .. kind
    local completed = waitForDashEnd(previousSerial, token)
    if OwnDashSerial > previousSerial then
        if kind == "LEFT" or kind == "RIGHT" then
            LastSideDash = os.clock()
        else
            LastFrontBackDash = os.clock()
        end
    end
    if not completed and token and token ~= ActionGeneration then
        ActiveDashTrack = nil
        ActiveOwnDashKind = nil
        stopAllInputs()
        return false
    end
    if completed then
        LastOwnDashKind = kind
        LastOwnDashEndedAt = os.clock()
        if wasOwnRagdolled then
            OwnRagdollEscapeSucceeded = true
            OwnRagdollEscapeKind = kind
            OwnRagdollRecoveryUntil = math.max(
                OwnRagdollRecoveryUntil,
                LastOwnDashEndedAt + CONFIG.OwnRagdollRecoveryTime)
        end
    elseif wasOwnRagdolled then
        OwnRagdollEscapeSucceeded = false
    end
    ActiveOwnDashKind = nil
    if completed and requireContact and not dashEndedInContact(targetRoot) then
        State = "DASH_NO_CONTACT"
        movementDirection(Vector3.zero)
        return false
    end
    movementDirection(Vector3.zero)
    State = "REPOSITIONING"
    return completed
end

local function ownDashIsActive()
    return ActiveOwnDashKind ~= nil
        or (ActiveDashTrack and ActiveDashTrack.IsPlaying == true)
end

local function immediateBlockAfterDash()
    local kind = ActiveOwnDashKind or LastOwnDashKind
    if kind ~= "LEFT" and kind ~= "RIGHT" and kind ~= "BACK" then
        return false
    end
    if ownDashIsActive() then return true end
    return os.clock() - LastOwnDashEndedAt <= CONFIG.DashBlockGrace
end

local function chooseOwnRagdollEscapeDirection(targetRoot)
    local camera = workspace.CurrentCamera
    local forward = camera and flat(camera.CFrame.LookVector)
        or flat(Root.CFrame.LookVector)
    local right = camera and flat(camera.CFrame.RightVector)
        or flat(Root.CFrame.RightVector)
    forward = unitOr(forward, flat(Root.CFrame.LookVector).Unit)
    right = unitOr(right, Vector3.new(1, 0, 0))

    local targetToUs = flat(Root.Position - targetRoot.Position)
    local sideSign = targetToUs:Dot(right) >= 0 and 1 or -1
    local targetSideSpeed = flat(targetRoot.AssemblyLinearVelocity):Dot(right)
    if math.abs(targetSideSpeed) > 2 then
        sideSign = targetSideSpeed > 0 and -1 or 1
    end

    local side = right * sideSign
    if dashCooldownReady(classifyDashDirection(side)) then
        return side
    end

    local back = -forward
    if dashCooldownReady(classifyDashDirection(back)) then
        return back
    end

    return side
end

local function disconnectTarget()
    for _, connection in ipairs(TargetConnections) do
        pcall(function() connection:Disconnect() end)
    end
    PendingBlock = nil
    releaseAutoBlock()
    TargetConnections = {}
    TargetConnection = nil
    CurrentTargetCharacter = nil
    TargetTrackSeen = {}
    clearTargetBlockState()
    LastBlockCircleReactionAt = -math.huge
end

local function targetDashIsThreatening(targetRoot)
    if not Root or not targetRoot then return false end
    local toUs = flat(Root.Position - targetRoot.Position)
    if toUs.Magnitude < 0.05 then return true end
    toUs = toUs.Unit
    local facing = unitOr(flat(targetRoot.CFrame.LookVector), toUs)
    local velocity = flat(targetRoot.AssemblyLinearVelocity)
    return facing:Dot(toUs) > 0.05 or velocity:Dot(toUs) > 2
end

clearTargetBlockState = function(track)
    if track and TargetBlockTrack ~= track then return end
    if TargetIsBlocking and CurrentTarget then
        RS.TargetBlockEndedAt = os.clock()
    end
    TargetBlockTrack = nil
    TargetIsBlocking = false
    TargetBlockStartedAt = 0
    BlockCircleSideSign = nil
end

local function setTargetBlockTrack(target, track)
    if target ~= CurrentTarget or not track then return false end
    if TargetBlockTrack == track and TargetIsBlocking then return false end

    TargetBlockTrack = track
    TargetIsBlocking = track.IsPlaying == true
    TargetBlockStartedAt = os.clock()

    local blockTrack = track
    local stoppedConnection = track.Stopped:Connect(function()
        clearTargetBlockState(blockTrack)
    end)
    table.insert(TargetConnections, stoppedConnection)
    return TargetIsBlocking
end

local function targetBlockIsActive()
    if not TargetIsBlocking then return false end
    if not TargetBlockTrack or not TargetBlockTrack.IsPlaying then
        clearTargetBlockState()
        return false
    end
    return true
end

local function isBehindTarget(targetRoot)
    if not Root or not targetRoot then return false end
    local relative = flat(Root.Position - targetRoot.Position)
    if relative.Magnitude < 0.05 then return false end
    local toUs = relative.Unit
    local facing = unitOr(flat(targetRoot.CFrame.LookVector), -toUs)
    return facing:Dot(toUs) <= CONFIG.BlockBehindDot
end

local function chooseBlockCircleDirection(targetRoot)
    if not Root or not targetRoot then return Vector3.zero end

    local relative = flat(Root.Position - targetRoot.Position)
    local distance = relative.Magnitude
    local right = unitOr(flat(targetRoot.CFrame.RightVector), Vector3.new(1, 0, 0))
    local sideOffset = relative:Dot(right)
    local targetSideSpeed = flat(targetRoot.AssemblyLinearVelocity):Dot(right)
    if not BlockCircleSideSign then
        BlockCircleSideSign = sideOffset >= 0 and -1 or 1
        if math.abs(targetSideSpeed) > 2 then
            BlockCircleSideSign = targetSideSpeed > 0 and -1 or 1
        end
    end

    local side = right * BlockCircleSideSign
    local radial = Vector3.zero
    if distance > CONFIG.M1Range then
        radial = unitOr(flat(targetRoot.Position - Root.Position), side) * 0.75
    elseif distance < CONFIG.M1MinRange then
        radial = unitOr(relative, side) * 0.85
    end
    return unitOr(side * 0.90 + radial, side)
end

local function queueBlockCircleReaction(target, track)
    if not CONFIG.Enabled or not CONFIG.BlockCircleEnabled
        or target ~= CurrentTarget or not target or not target.Character
        or not alive(target.Character) then
        return false
    end
    if PendingReaction and PendingReaction.target == target
        and PendingReaction.reaction == "BLOCK_CIRCLE" then
        return true
    end

    local now = os.clock()
    if now - LastBlockCircleReactionAt < CONFIG.ReactionDuplicateWindow then
        return true
    end
    LastBlockCircleReactionAt = now
    BlockCircleSideSign = nil
    PendingReaction = {
        target = target,
        reaction = "BLOCK_CIRCLE",
        id = BLOCK_ANIMATION_ID,
        track = track,
        time = now,
    }
    invalidateAction()
    stopAttackInputs()
    State = "REACTION_PENDING_BLOCK_CIRCLE"
    return true
end

local function refreshTargetBlockState(target)
    if target ~= CurrentTarget or not target or not target.Character then
        clearTargetBlockState()
        return false
    end

    local humanoid = target.Character:FindFirstChildOfClass("Humanoid")
    local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        clearTargetBlockState()
        return false
    end

    local foundTrack
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        if animationId(track) == BLOCK_ANIMATION_ID and track.IsPlaying then
            foundTrack = track
            break
        end
    end

    if foundTrack then
        local becameActive = setTargetBlockTrack(target, foundTrack)
        if becameActive then
            queueBlockCircleReaction(target, foundTrack)
        end
        return true
    end

    clearTargetBlockState()
    return false
end

RF.REACTION_PRIORITY = {
    RAGDOLL = 98, RETREAT_FAR = 95, BACK_DASH = 91, DASH_BEHIND = 90,
    EVADE = 82, BLOCK_CIRCLE = 80, INTERRUPT = 60, PUNISH = 50,
}
function RF.reactionPriority(reaction)
    return RF.REACTION_PRIORITY[reaction] or 40
end

-- R1: rule-aware. `source` is the attacking player when it is not the
-- current target (external threat); movement is computed from the source.
local function requestReaction(target, reaction, id, track, rule, source)
    if not CONFIG.Enabled or CurrentTarget ~= target then return end
    if not target or not target.Character or not alive(target.Character) then return end
    local sourcePlayer = source or target
    local sourceCharacter = sourcePlayer.Character
    if not sourceCharacter or not alive(sourceCharacter) then return end
    local sourceRoot = sourceCharacter:FindFirstChild("HumanoidRootPart")

    local distance = distanceTo(sourceCharacter)
    local range
    if reaction == "RAGDOLL" or reaction == "PUNISH" or reaction == "INTERRUPT" then
        range = math.huge -- the action re-checks the normal attack gate
    elseif rule and rule.detect then
        range = RF.dynamicReach(rule.detect, sourceRoot) + 2
    else
        range = reaction == "RETREAT_FAR" and CONFIG.LongThreatDistance or CONFIG.ReactionDistance
    end
    if distance > range then return end

    local now = os.clock()
    for seenTrack, seenAt in pairs(TargetTrackSeen) do
        if type(seenAt) == "table" and now - seenAt.time > 3 then
            TargetTrackSeen[seenTrack] = nil
        end
    end

    if track then
        local position = track.TimePosition or 0
        local previous = TargetTrackSeen[track]
        if previous and now - previous.time < 0.1
            and math.abs(position - previous.position) < 0.05 then
            return
        end
        TargetTrackSeen[track] = {time = now, position = position}
    end

    if PendingReaction
        and PendingReaction.target == target
        and PendingReaction.reaction == reaction
        and now - PendingReaction.time < CONFIG.ReactionDuplicateWindow then
        return
    end
    if PendingReaction and PendingReaction.target == target
        and now - PendingReaction.time < 0.30
        and RF.reactionPriority(reaction) < RF.reactionPriority(PendingReaction.reaction) then
        return
    end
    if reaction ~= "RAGDOLL"
        and now - LastReaction < CONFIG.ReactionLockout
        and PendingReaction
        and PendingReaction.target == target then
        return
    end

    LastReaction = now
    PendingReaction = {
        target = target,
        reaction = reaction,
        id = id,
        track = track,
        time = now,
        rule = rule,
        source = source,
    }
    invalidateAction()
    State = "REACTION_PENDING_" .. reaction
    if reaction ~= "PUNISH" and reaction ~= "INTERRUPT"
        and (not ActiveDashTrack or not ActiveDashTrack.IsPlaying) and sourceRoot then
        faceTarget(sourceRoot, true)
        movementDirection(combatMovementDirection(sourceRoot, "REACTION"), "REACTION")
    end
end

local function blockTargetWillReach(targetRoot, range)
    if not Root or not targetRoot then return false end
    range = range or CONFIG.BlockRange
    local offset = flat(targetRoot.Position - Root.Position)
    local distance = offset.Magnitude
    if distance <= range then return true end
    if distance < 0.05 then return true end

    local towardUs = -offset.Unit
    local closingSpeed = flat(targetRoot.AssemblyLinearVelocity):Dot(towardUs)
    return closingSpeed > 0
        and distance - closingSpeed * CONFIG.BlockReachHorizon <= range
end

-- R1: per-rule detect / commit range / facing / hold / max hold.
-- M1s keep the MK.1 numbers (20 detect, 8 commit, 0.20 hold, 0.80 max).
local function queueAutoBlock(target, id, track, rule)
    if not CONFIG.Enabled or not CONFIG.EnableAutoBlock then return false end
    local kind = id and BLOCK_KIND_BY_ID[id]
    if not kind or DOWNSLAM_IDS[id] then return false end
    if not target or not target.Character or not alive(target.Character) then return false end

    local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot or not Root then return false end
    rule = rule or RULES[id] or M1_RULE
    local detectRange = rule.detect or CONFIG.BlockDetectRange
    local commitRange = rule.blockRange or CONFIG.BlockRange
    local distance = flat(targetRoot.Position - Root.Position).Magnitude
    if distance > RF.dynamicReach(detectRange, targetRoot) then
        return false
    end
    if rule.facing and not RF.aimedAtUs(targetRoot) then
        return false
    end
    if distance > commitRange and not blockTargetWillReach(targetRoot, commitRange)
        and (kind ~= "DASH" or not targetDashIsThreatening(targetRoot)) then
        return false
    end

    local now = os.clock()
    local position = track and track.TimePosition or 0
    local hold = rule.hold or CONFIG.BlockHoldTime
    local maxHold = rule.blockMax
    if not maxHold then
        if kind == "ATTACK" then
            -- multi-hit / long blockables: guard while the track plays
            local length = RF.trackLength(track, id)
            local remaining = math.max(0, length - position)
            maxHold = math.clamp(remaining, CONFIG.BlockMaxHoldTime, CONFIG.AttackBlockMaxCap)
        else
            maxHold = CONFIG.BlockMaxHoldTime
        end
    end
    maxHold = math.max(maxHold, hold)

    local measured = M1_TIMINGS[id]
    local readyAt = now
    local expectedEndAt = now + hold
    if CONFIG.UseBlockTimings and measured then
        local remaining = math.max(0, measured - position)
        readyAt = now + math.max(0, remaining - CONFIG.BlockLead)
        expectedEndAt = now + remaining + CONFIG.BlockTrail
    end
    expectedEndAt = math.max(expectedEndAt, readyAt + hold)
    if immediateBlockAfterDash() then
        readyAt = now
        expectedEndAt = now + hold
    end

    if PendingBlock and PendingBlock.target == target
        and PendingBlock.readyAt <= readyAt
        and PendingBlock.expectedEndAt >= expectedEndAt then
        return true
    end

    PendingBlock = {
        target = target,
        id = id,
        kind = kind,
        track = track,
        readyAt = readyAt,
        expectedEndAt = expectedEndAt,
        queuedAt = now,
        range = commitRange,
        maxHold = maxHold,
    }
    local dashInProgress = ownDashIsActive()
    if not IsBlocking and not dashInProgress then
        -- A block request is an interrupt. Cancel any attack/reaction task
        -- before it can send its next input.
        invalidateAction()
        PendingReaction = nil
        Busy = false
        ActionStartedAt = 0
        stopAttackInputs()
    end
    State = dashInProgress and "BLOCK_QUEUED_AFTER_DASH"
        or "BLOCK_QUEUED_" .. kind
    return true
end

local function beginAutoBlock(target, pending, targetRoot)
    if IsBlocking then return true end
    if ownDashIsActive() then return false end
    if not targetRoot or not blockTargetWillReach(targetRoot, pending.range) then return false end

    invalidateAction()
    PendingReaction = nil
    Busy = false
    ActionStartedAt = 0
    stopAttackInputs()
    releaseMoveKeys()
    faceTarget(targetRoot, true)
    sendKey(Enum.KeyCode.F, true)

    IsBlocking = true
    BlockTrack = pending.track
    BlockId = pending.id
    BlockKind = pending.kind
    BlockStartedAt = os.clock()
    RS.BlockMaxHold = pending.maxHold or CONFIG.BlockMaxHoldTime
    BlockExpectedEnd = math.max(pending.expectedEndAt,
        BlockStartedAt + CONFIG.BlockHoldTime)
    PendingBlock = nil
    movementDirection(combatMovementDirection(targetRoot, "BLOCK"), "BLOCK")
    State = "AUTO_BLOCK_" .. tostring(BlockKind)
    return true
end

local function processAutoBlock(target, targetRoot)
    if not CONFIG.Enabled or not CONFIG.EnableAutoBlock
        or not target or not targetRoot or not Humanoid or Humanoid.Health <= 0
        or Humanoid.PlatformStand or isRagdolled(target.Character) then
        PendingBlock = nil
        releaseAutoBlock()
        return false
    end

    local now = os.clock()
    if IsBlocking then
        local trackPlaying = BlockTrack and BlockTrack.IsPlaying
        -- R5: remember where the guarded track was; if it stops well short of
        -- its length (attacker stunned or cancelled) drop the guard at once.
        if trackPlaying then
            RS.BlockTrackLastPos = BlockTrack.TimePosition or 0
            RS.BlockTrackStoppedAt = nil
        elseif BlockTrack then
            RS.BlockTrackStoppedAt = RS.BlockTrackStoppedAt or now
            local length = RF.trackLength(BlockTrack, BlockId)
            local cutShort = length > 0
                and (RS.BlockTrackLastPos or 0) < length - CONFIG.EarlyStopMargin
            if cutShort and now - RS.BlockTrackStoppedAt >= CONFIG.EarlyStopRelease then
                releaseAutoBlock()
                State = "BLOCK_RELEASED_EARLY_STOP"
                return false
            end
        end
        if now - BlockStartedAt < (RS.BlockMaxHold or CONFIG.BlockMaxHoldTime)
            and (trackPlaying or now < BlockExpectedEnd) then
            faceTarget(targetRoot, true)
            movementDirection(combatMovementDirection(targetRoot, "BLOCK"), "BLOCK")
            State = "AUTO_BLOCK_" .. tostring(BlockKind)
            return true
        end
        releaseAutoBlock()
        State = "BLOCK_RELEASED"
        return false
    end

    local pending = PendingBlock
    if not pending or pending.target ~= target then
        PendingBlock = nil
        return false
    end

    if not pending.track or (not pending.track.IsPlaying and now > pending.expectedEndAt) then
        PendingBlock = nil
        return false
    end

    if ownDashIsActive() then
        faceTarget(targetRoot, true)
        movementDirection(combatMovementDirection(targetRoot, "BLOCK"), "BLOCK")
        State = immediateBlockAfterDash()
            and "BLOCK_AFTER_DASH"
            or "BLOCK_QUEUED_AFTER_DASH"
        return true
    end

    -- Once a known attack is queued, let the block scheduler own the next
    -- short decision so an M1 tap cannot race the block input.
    faceTarget(targetRoot, true)
    movementDirection(combatMovementDirection(targetRoot, "BLOCK"), "BLOCK")
    if now < pending.readyAt then
        State = "BLOCK_QUEUED_" .. tostring(pending.kind)
        return true
    end

    if not blockTargetWillReach(targetRoot, pending.range) then
        if pending.kind == "DASH" and pending.track and pending.track.IsPlaying then
            State = "BLOCK_QUEUED_DASH"
            return true
        end
        PendingBlock = nil
        return false
    end
    return beginAutoBlock(target, pending, targetRoot)
end

-- R1: the target's tracks go into the watch list; the watch list decides
-- (each heartbeat) whether range / facing / trigger timing allow an action.
local function handleTargetAnimation(target, character, track)
    if target ~= CurrentTarget or character ~= target.Character then return end
    local id = animationId(track)
    if not track.IsPlaying then return end

    if id == BLOCK_ANIMATION_ID then
        setTargetBlockTrack(target, track)
        queueBlockCircleReaction(target, track)
        return
    end

    local rule = RF.ruleFor(id)
    if not rule then return end
    RF.registerThreat(target, track, id, rule, false)
    -- evaluate immediately: no heartbeat of latency on instant threats
    local watch = RS.ThreatWatches[track]
    local root = character:FindFirstChild("HumanoidRootPart")
    if watch and root and Root and not watch.triggered
        and RF.triggerReached(track, rule, id) and RF.dispatchThreat(watch, root) then
        watch.triggered = true
        watch.rearmAt = os.clock() + CONFIG.WatchRearmDelay
    end
end

local function bindTargetCharacter(target, character)
    if target ~= CurrentTarget or character ~= target.Character then return end
    CurrentTargetCharacter = character
    TargetTrackSeen = {}
    if TargetConnection then
        pcall(function() TargetConnection:Disconnect() end)
        TargetConnection = nil
    end

    task.spawn(function()
        local h = character:FindFirstChildOfClass("Humanoid")
            or character:WaitForChild("Humanoid", 1)
        local animator = h and (h:FindFirstChildOfClass("Animator")
            or h:WaitForChild("Animator", 1))
        if target ~= CurrentTarget or character ~= target.Character or not animator then return end
        TargetConnection = animator.AnimationPlayed:Connect(function(track)
            handleTargetAnimation(target, character, track)
        end)
        table.insert(TargetConnections, TargetConnection)
    end)
end

local function connectTarget(target)
    disconnectTarget()
    CurrentTarget = target
    NextApproachUpdate = 0
    LastTargetPosition = nil
    LastTargetRagdolled = false
    TargetGetupIFrameUntil = 0
    RagdollComboDone = false
    NextRagdollTry = 0
    clearTargetBlockState()
    LastBlockCircleReactionAt = -math.huge
    RS.ApproachDashRoll = nil
    for _, watch in pairs(RS.ThreatWatches) do
        watch.external = watch.player ~= target
    end
    if not target then return end

    table.insert(TargetConnections, target.CharacterAdded:Connect(function(character)
        if target ~= CurrentTarget then return end
        bindTargetCharacter(target, character)
    end))

    if target.Character then
        bindTargetCharacter(target, target.Character)
    end
end

local function chooseBehindDirection(targetRoot)
    local behind = targetRoot.Position - targetRoot.CFrame.LookVector * 5
    local desired = flat(behind - Root.Position)
    if desired.Magnitude > 1 then return desired.Unit end

    local right = unitOr(flat(targetRoot.CFrame.RightVector), Vector3.new(1, 0, 0))
    local relative = flat(Root.Position - targetRoot.Position)
    local sign = relative:Dot(right) >= 0 and 1 or -1
    local targetSideSpeed = flat(targetRoot.AssemblyLinearVelocity):Dot(right)
    if math.abs(targetSideSpeed) > 1 then
        sign = targetSideSpeed > 0 and -1 or 1
    end
    return right * sign
end

local function canAttack(targetRoot, maxRange)
    local distance = targetRoot and Root
        and (flat(targetRoot.Position - Root.Position)).Magnitude
    return targetRoot and Root and Humanoid and Humanoid.Health > 0
        and targetCanReceiveM1(targetRoot.Parent)
        and (not targetBlockIsActive() or isBehindTarget(targetRoot))
        and distance >= (RS.M1MinOverride or CONFIG.M1MinRange)
        and distance <= (maxRange or CONFIG.M1Range)
        and not RF.threatLockActive()          -- R1: live hold-until-stop / counter
        and not RF.friendlyInAttackCone(targetRoot) -- R1: never swing through a friend
end

-- ===================== R1: threat engine =====================
function RF.ruleFor(id)
    if not id then return nil end
    local rule = RULES[id]
    if rule then return rule end
    if M1_IDS[id] or UPPERCUT_IDS[id] then return M1_RULE end
    if DASH_IDS[id] then return DASH_RULE end
    return nil
end

function RF.registerThreat(player, track, id, rule, external)
    if RS.ThreatWatches[track] then return end
    RS.ThreatWatches[track] = {
        player = player, track = track, id = id, rule = rule,
        startedAt = os.clock(), triggered = false, external = external,
    }
end

function RF.trackLength(track, id)
    local length = track and track.Length or 0
    if length > 0 then
        if id then RS.LengthCache[id] = length end
        return length
    end
    return id and RS.LengthCache[id] or 0
end

function RF.triggerReached(track, rule, id)
    if not track or not track.IsPlaying then return false end
    if not rule.trigAt and not rule.trigFrac and not rule.trigEnd then return true end
    local position = track.TimePosition or 0
    local length = RF.trackLength(track, id)
    local at
    if rule.trigAt then
        at = rule.trigAt
    elseif length <= 0 then
        return true -- length unknown: safety over dash economy
    elseif rule.trigFrac then
        at = length * rule.trigFrac
    else
        at = math.max(0, length - rule.trigEnd)
    end
    local lead = 0
    if rule.mode == "BLOCK" or rule.mode == "BLOCK_OR_SIDE" then
        lead = CONFIG.BlockTriggerLead
    elseif rule.mode == "SIDE_DASH" or rule.mode == "BACK_DASH"
        or rule.mode == "INTERRUPT_OR_SIDE" then
        lead = CONFIG.EvadeTriggerLead
    end
    return position >= math.max(0, at - lead)
end

RF.LOCK_PRIORITY = {RETREAT = 3, NO_ATTACK = 3, BACK = 2, SIDE = 2}

function RF.setThreatLock(watch, kind)
    local rule = watch.rule
    if not rule.untilStop and not rule.maxHold then return end
    local now = os.clock()
    local current = RS.ThreatLock
    if current and RF.threatLockActive()
        and (RF.LOCK_PRIORITY[current.kind] or 0) > (RF.LOCK_PRIORITY[kind] or 0) then
        return
    end
    local cap = rule.maxHold
    if not cap then
        local length = RF.trackLength(watch.track, watch.id)
        cap = length > 0 and math.min(length + 0.2, 6) or CONFIG.DefaultThreatHold
    end
    RS.ThreatLock = {
        kind = kind, rule = rule, id = watch.id, player = watch.player,
        track = rule.untilStop and watch.track or nil,
        untilAt = now + cap, stopAt = nil,
    }
end

function RF.threatLockActive()
    local lock = RS.ThreatLock
    if not lock then return false end
    local now = os.clock()
    if lock.track and not lock.track.IsPlaying and not lock.stopAt then
        lock.stopAt = now
    end
    local character = lock.player and lock.player.Character
    if now >= lock.untilAt
        or (lock.stopAt and now - lock.stopAt >= CONFIG.ThreatSafetyTail)
        or not character or not alive(character) then
        RS.ThreatLock = nil
        return false
    end
    return true
end

-- Movement while a lock is live. RETREAT runs (toward an ally when low),
-- SIDE leaves the attacker's forward cone, BACK opens distance, NO_ATTACK
-- orbits outside M1 reach.
function RF.lockMovementDirection(lock, sourceRoot)
    local relative = flat(Root.Position - sourceRoot.Position)
    local distance = relative.Magnitude
    local away = unitOr(relative, -flat(sourceRoot.CFrame.LookVector))
    local right = unitOr(flat(sourceRoot.CFrame.RightVector), Vector3.new(1, 0, 0))
    local sign = relative:Dot(right) >= 0 and 1 or -1
    local side = right * sign
    local direction
    if lock.kind == "RETREAT" then
        local safe = (lock.rule.detect or CONFIG.LongThreatDistance) + 4
        direction = distance < safe and RF.fallbackBias(away) or side
    elseif lock.kind == "SIDE" then
        direction = unitOr(side + away * 0.35, side)
    elseif lock.kind == "BACK" then
        direction = distance < 16 and away or side
    else -- NO_ATTACK
        local radial = distance < 9 and away * 0.8 or (distance > 12 and -away * 0.5 or Vector3.zero)
        direction = unitOr(side + radial, side)
    end
    return RF.applyFriendSeparation(direction)
end

RF.LOCK_KIND = {
    SIDE_DASH = "SIDE", INTERRUPT_OR_SIDE = "SIDE", BLOCK_OR_SIDE = "SIDE",
    BACK_DASH = "BACK", RETREAT = "RETREAT", NO_ATTACK = "NO_ATTACK",
}
RF.EVADE_REACTION = {
    SIDE_DASH = "EVADE", INTERRUPT_OR_SIDE = "EVADE", BLOCK_OR_SIDE = "EVADE",
    BACK_DASH = "BACK_DASH", RETREAT = "RETREAT_FAR",
}

-- Unblockable threat while guarding (e.g. side dash into Flowing Water):
-- holding F is now the losing option, so drop it before evading.
RF.UNBLOCKABLE_KIND = {SIDE = true, BACK = true, RETREAT = true}
function RF.dropGuardFor(kind)
    if not RF.UNBLOCKABLE_KIND[kind] then return end
    if IsBlocking or PendingBlock then
        PendingBlock = nil
        releaseAutoBlock()
        State = "GUARD_DROPPED_UNBLOCKABLE"
    end
end

-- A threat from someone who is not the current target.
function RF.dispatchExternal(watch, sourceRoot, distance, aimed)
    local rule, mode = watch.rule, watch.rule.mode
    if not aimed and mode ~= "RETREAT" and mode ~= "NO_ATTACK" then return false end
    if mode == "M1" or mode == "BLOCK" or mode == "BLOCK_OR_SIDE" then
        -- An attacker in our face becomes the target unless a string is live.
        if distance <= CONFIG.ExternalRetargetRange and not RS.ChainLive
            and validTarget(watch.player) then
            invalidateAction()
            RS.SelfDefense = {player = watch.player, untilAt = os.clock() + CONFIG.SelfDefenseHold}
            connectTarget(watch.player)
            State = "TARGET_SWITCHED_THREAT"
            return false -- re-evaluated next frame as a target threat
        end
        return false
    end
    local kind = RF.LOCK_KIND[mode]
    if not kind then return false end
    RF.dropGuardFor(kind)
    RF.setThreatLock(watch, kind)
    local reaction = RF.EVADE_REACTION[mode]
    if reaction and CurrentTarget then
        requestReaction(CurrentTarget, reaction, watch.id, watch.track, rule, watch.player)
    end
    return true
end

-- Returns true when handled (the watch stops re-evaluating).
function RF.dispatchThreat(watch, sourceRoot)
    if not Root or not CONFIG.Enabled then return false end
    local rule, id, track, player = watch.rule, watch.id, watch.track, watch.player
    local mode = rule.mode
    local distance = flat(sourceRoot.Position - Root.Position).Magnitude
    local baseDetect = rule.detect
        or (mode == "M1" and CONFIG.BlockDetectRange)
        or CONFIG.ReactionDistance
    if distance > RF.dynamicReach(baseDetect, sourceRoot) then return false end
    local aimed = RF.aimedAtUs(sourceRoot)
    if rule.facing and not aimed then return false end

    if watch.external and player ~= CurrentTarget then
        return RF.dispatchExternal(watch, sourceRoot, distance, aimed)
    end
    if player ~= CurrentTarget then return false end

    -- Team: the enemy is swinging at an ally beside us, not at us. Keep
    -- fighting instead of guarding; re-evaluated if they turn to us.
    if RF.teamModeActive() and not aimed
        and mode ~= "RETREAT" and mode ~= "NO_ATTACK" and mode ~= "DASH"
        and RF.allyNearRoot(sourceRoot, CONFIG.AllyBlockFacingRange) then
        return false
    end

    -- R14: windup interrupt. Close enough and still inside the window: hit
    -- first. Tried once per track; the normal answer covers a failed try.
    -- R16: point-blank counts (e.g. they block our M1s up close, then swap
    -- into Normal Punch): min range drops to the tech range, and the M1
    -- safety wait is ignored -- if we are still in M1 recovery the tap just
    -- fails to confirm and the normal answer takes over.
    local interruptOpen = false
    if rule.interruptWindow and not watch.interruptTried
        and (track.TimePosition or 0) <= rule.interruptWindow
        and distance <= CONFIG.InterruptRange and not RS.ChainLive then
        RS.M1MinOverride = CONFIG.TechM1MinRange
        interruptOpen = canAttack(sourceRoot, CONFIG.M1CommitRange)
        RS.M1MinOverride = nil
    end
    if interruptOpen then
        watch.interruptTried = true
        -- give the hit time to land before the normal answer may take over
        watch.interruptUntil = os.clock()
            + math.max(0.3, rule.interruptWindow - (track.TimePosition or 0) + 0.3)
        requestReaction(player, "INTERRUPT", id, track, rule)
        return true
    end

    if mode == "M1" or mode == "DASH" or mode == "BLOCK" or mode == "BLOCK_OR_SIDE" then
        if queueAutoBlock(player, id, track, rule) then return true end
        if mode == "DASH" then
            if not watch.behindDone and distance <= CONFIG.DashBehindMaxRange
                and targetDashIsThreatening(sourceRoot) then
                watch.behindDone = true
                requestReaction(player, "DASH_BEHIND", id, track, rule)
                return true
            end
            return false -- far dash: keep tracking it, block when it arrives
        end
        if mode == "BLOCK_OR_SIDE" then
            RF.setThreatLock(watch, "SIDE")
            requestReaction(player, "EVADE", id, track, rule)
            return true
        end
        -- M1 / BLOCK not reachable yet: keep watching. A whiffed swing is
        -- never answered with a dash.
        return false
    end

    if mode == "INTERRUPT" or mode == "INTERRUPT_OR_SIDE" then
        if canAttack(sourceRoot, CONFIG.M1CommitRange)
            and os.clock() >= NextM1AllowedAt and not RS.ChainLive then
            requestReaction(player, "INTERRUPT", id, track, rule)
            return true
        end
        if mode == "INTERRUPT_OR_SIDE" then
            RF.dropGuardFor("SIDE")
            RF.setThreatLock(watch, "SIDE")
            requestReaction(player, "EVADE", id, track, rule)
            return true
        end
        return false
    end

    local kind = RF.LOCK_KIND[mode]
    if kind then
        RF.dropGuardFor(kind)
        RF.setThreatLock(watch, kind)
        local reaction = RF.EVADE_REACTION[mode]
        if reaction then
            requestReaction(player, reaction, id, track, rule)
        end
        return true
    end
    return false -- PUNISH acts when the track stops
end

-- R4: a handled track stays live. It is re-evaluated unless the response
-- to it is still in effect (guard up / queued for it, or its lock active).
RF.ONE_SHOT = {INTERRUPT = true, INTERRUPT_OR_SIDE = true, PUNISH = true}
function RF.watchNeedsEval(watch, now)
    if not watch.triggered then return true end
    if now < (watch.rearmAt or 0) or now < (watch.interruptUntil or 0) then return false end
    local rule = watch.rule
    local mode = rule.mode
    if RF.ONE_SHOT[mode] then return false end
    if mode == "M1" or mode == "DASH" or mode == "BLOCK" or mode == "BLOCK_OR_SIDE" then
        if (IsBlocking and BlockTrack == watch.track)
            or (PendingBlock and PendingBlock.track == watch.track) then
            return false
        end
        return true
    end
    -- evasive / no-attack: covered while its lock lives; lock-less rules fire once
    if not rule.untilStop and not rule.maxHold then return false end
    local lock = RS.ThreatLock
    if lock and RF.threatLockActive() and lock.player == watch.player
        and (lock.track == watch.track or lock.id == watch.id) then
        return false
    end
    return true
end

-- R4: sweep every nearby enemy's playing tracks. Catches tracks that began
-- before we bound to them, began out of range, or whose AnimationPlayed was
-- missed; the trigger check still applies from their current time position.
function RF.scanPlayingTracks(now)
    if now < RS.NextTrackScan then return end
    RS.NextTrackScan = now + CONFIG.TrackScanInterval
    if not Root then return end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and not RF.isFriend(player) and alive(player.Character)
            and distanceTo(player.Character) <= CONFIG.TrackScanRadius then
            local h = player.Character:FindFirstChildOfClass("Humanoid")
            local animator = h and h:FindFirstChildOfClass("Animator")
            local ok, tracks = pcall(function() return animator and animator:GetPlayingAnimationTracks() end)
            if ok and tracks then
                local isTarget = player == CurrentTarget
                for _, track in ipairs(tracks) do
                    if track.IsPlaying and not RS.ThreatWatches[track] then
                        local id = animationId(track)
                        local rule = RF.ruleFor(id)
                        if rule and (isTarget or (rule.mode ~= "PUNISH"
                            and rule.mode ~= "INTERRUPT" and rule.mode ~= "DASH")) then
                            RF.registerThreat(player, track, id, rule, not isTarget)
                        end
                    end
                end
            end
        end
    end
end

function RF.processThreatWatches(target)
    local now = os.clock()
    local stopped = {}
    for track, watch in pairs(RS.ThreatWatches) do
        local character = watch.player and watch.player.Character
        local sourceRoot = character and character:FindFirstChild("HumanoidRootPart")
        if not sourceRoot or not alive(character) or now - watch.startedAt > 12 then
            RS.ThreatWatches[track] = nil
        elseif not track.IsPlaying then
            RS.ThreatWatches[track] = nil
            table.insert(stopped, watch)
        elseif RF.watchNeedsEval(watch, now) and RF.triggerReached(track, watch.rule, watch.id)
            and RF.dispatchThreat(watch, sourceRoot) then
            watch.triggered = true
            watch.rearmAt = now + CONFIG.WatchRearmDelay
        end
    end
    -- R14: punish before the end ("stops attacking Xs before it ends")
    for track, watch in pairs(RS.ThreatWatches) do
        local before = watch.rule.punishBeforeEnd
        if before and not watch.punished and watch.player == target and target == CurrentTarget
            and track.IsPlaying and not RS.ChainLive then
            local length = RF.trackLength(track, watch.id)
            if length > 0 and length - (track.TimePosition or 0) <= before then
                watch.punished = true
                if IsBlocking and BlockTrack == track then releaseAutoBlock() end
                if PendingBlock and PendingBlock.track == track then PendingBlock = nil end
                local lock = RS.ThreatLock
                if lock and lock.player == target and (lock.track == track or lock.id == watch.id) then
                    RS.ThreatLock = nil
                end
                requestReaction(target, "PUNISH", watch.id, nil, watch.rule)
            end
        end
    end
    for _, watch in ipairs(stopped) do
        if watch.rule.punish and not watch.punished and watch.player == target and target == CurrentTarget
            and not RS.ChainLive and not RF.threatLockActive() then
            requestReaction(target, "PUNISH", watch.id, nil, watch.rule)
        end
    end
end

function RF.handleExternalAnimation(player, character, track)
    if not CONFIG.Enabled or not CONFIG.ExternalThreats then return end
    if player == LocalPlayer or player == CurrentTarget or RF.isFriend(player) then return end
    if character ~= player.Character or not track.IsPlaying then return end
    local id = animationId(track)
    local rule = RF.ruleFor(id)
    if not rule or rule.mode == "PUNISH" or rule.mode == "INTERRUPT" or rule.mode == "DASH" then
        return
    end
    if distanceTo(character) > CONFIG.TrackScanRadius then return end
    RF.registerThreat(player, track, id, rule, true)
end

function RF.bindExternalPlayer(player)
    if player == LocalPlayer or RS.ExternalConnections[player] then return end
    local connections = {}
    RS.ExternalConnections[player] = connections
    local function bindCharacter(character)
        task.spawn(function()
            local h = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
            local animator = h and (h:FindFirstChildOfClass("Animator") or h:WaitForChild("Animator", 5))
            if not animator or RS.ExternalConnections[player] ~= connections then return end
            table.insert(connections, animator.AnimationPlayed:Connect(function(track)
                RF.handleExternalAnimation(player, character, track)
            end))
        end)
    end
    table.insert(connections, player.CharacterAdded:Connect(bindCharacter))
    if player.Character then bindCharacter(player.Character) end
end

function RF.unbindExternalPlayer(player)
    local connections = RS.ExternalConnections[player]
    if not connections then return end
    RS.ExternalConnections[player] = nil
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
end

-- Offensive dashes never spend the last ready bucket (side vs front/back),
-- unless the target is ragdolled and cannot answer.
function RF.offensiveDashAllowed(kind, target)
    if not CONFIG.DashReserveEnabled then return true end
    local character = target and target.Character
    if character and isRagdolled(character) then return true end
    if kind == "LEFT" or kind == "RIGHT" then
        return dashCooldownReady("BACK")
    end
    return dashCooldownReady("LEFT")
end

-- Direct short block for BLOCK_OR_SIDE when every dash is cooling.
function RF.reactionBlockFallback(target, pending, token)
    local rule = pending.rule
    if not rule or (rule.mode ~= "BLOCK_OR_SIDE" and rule.mode ~= "BLOCK") then return false end
    local targetRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot or not blockTargetWillReach(targetRoot, rule.blockRange) then return false end
    local hold = rule.hold or CONFIG.BlockHoldTime
    local maxHold = math.max(hold, math.min(rule.blockMax or 0.6, 0.6))
    State = "REACTION_BLOCK_FALLBACK"
    faceTarget(targetRoot, true)
    sendKey(Enum.KeyCode.F, true)
    local started = os.clock()
    while CONFIG.Enabled and os.clock() - started < maxHold do
        if token and token ~= ActionGeneration then break end
        if os.clock() - started >= hold and pending.track and not pending.track.IsPlaying then break end
        targetRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        if not targetRoot then break end
        faceTarget(targetRoot, true)
        RunService.Heartbeat:Wait()
    end
    sendKey(Enum.KeyCode.F, false)
    return true
end

local function waitForOwnM1(previousSerial, token, target, allowTargetStateChange)
    local started = os.clock()
    while os.clock() - started < CONFIG.M1ConfirmTimeout do
        if not actionStillValid(token, target) then return nil end
        if not allowTargetStateChange
            and target and target.Character
            and not targetCanReceiveM1(target.Character) then
            return nil, "TARGET_NOT_ATTACKABLE"
        end
        if OwnM1Serial > previousSerial then
            return LastOwnM1Id, OwnM1Stage
        end
        RunService.Heartbeat:Wait()
    end
    return nil
end

local function resolveFinishMode(target)
    local targetCharacter = target and target.Character
    local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
    local targetHumanoid = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")
    if not targetRoot or not targetHumanoid then return "NEUTRAL" end
    if isRagdolled(targetCharacter) then return "NEUTRAL" end

    local falling = targetRoot.AssemblyLinearVelocity.Y < -3
        or targetRoot.Position.Y < Root.Position.Y - 1.5
    if CONFIG.EnableDownslam and falling then
        return "DOWNSLAM"
    end

    local grounded = targetHumanoid:GetState() == Enum.HumanoidStateType.Running
        or targetHumanoid:GetState() == Enum.HumanoidStateType.Landed
        or targetHumanoid:GetState() == Enum.HumanoidStateType.RunningNoPhysics
    if CONFIG.EnableUppercut and grounded then
        return "UPPERCUT"
    end
    return "NEUTRAL"
end

local function updateOwnM1Observation(id, track)
    local now = os.clock()
    if now - LastOwnM1At > 1.15 or OwnM1Stage >= 4 then
        OwnM1Stage = 0
        OwnM1SetIndex = nil
        LearnedM1Sequence = {}
        LearnedM1Stage = 0
    end

    if DOWNSLAM_IDS[id] or UPPERCUT_IDS[id] then
        OwnM1Stage = 4
        CurrentM1Stage = 4
        LastOwnM1Id = id
        LastOwnM1At = now
        ActiveOwnM1Track = track
        return
    end

    local options = M1_INFO_BY_ID[id]
    if not options then
        OwnM1SetIndex = nil
        CurrentM1Set = nil
        local stage = OwnM1Stage >= 4 and 1 or OwnM1Stage + 1
        if OwnM1Stage == 0 then stage = 1 end
        OwnM1Stage = math.min(stage, 4)
        CurrentM1Stage = OwnM1Stage
        LastOwnM1Id = id
        LastOwnM1At = now
        ActiveOwnM1Track = track
        LearnedM1Stage = OwnM1Stage
        LearnedM1Sequence[LearnedM1Stage] = id
        LastLearnedM1At = now
        return
    end
    local chosen
    if OwnM1SetIndex then
        for _, option in ipairs(options) do
            if option.setIndex == OwnM1SetIndex then
                chosen = option
                break
            end
        end
    end
    chosen = chosen or options[1]
    if not chosen then return end

    local stage = chosen.stage
    if OwnM1SetIndex == chosen.setIndex and OwnM1Stage == 3 and stage == 1 then
        stage = 4
    end

    OwnM1SetIndex = chosen.setIndex
    CurrentM1Set = M1_SETS[chosen.setIndex]
    OwnM1Stage = stage
    CurrentM1Stage = stage
    LastOwnM1Id = id
    LastOwnM1At = now
    ActiveOwnM1Track = track

    if LearnedM1Stage >= 4 or now - LastLearnedM1At > 1.15 then
        LearnedM1Sequence = {}
        LearnedM1Stage = 0
    end
    LearnedM1Stage = math.min(stage, 4)
    LearnedM1Sequence[LearnedM1Stage] = id
    LastLearnedM1At = now
end

local function waitForM4DashFollowup(target, token)
    M4FollowupActive = true
    local function finish(result)
        M4FollowupActive = false
        return result
    end

    local startedAt = os.clock()
    local followupDeadline = startedAt + CONFIG.M4DashFollowupWindow
    local foundRagdoll = false

    while os.clock() < followupDeadline do
        if not actionStillValid(token, target) then return finish(false) end
        local character = target.Character
        local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
        if not targetRoot then return finish(false) end

        if isRagdolled(character) then
            foundRagdoll = true
            local offset = flat(targetRoot.Position - Root.Position)
            if offset.Magnitude > CONFIG.DashContactRange and not RF.hgWalkupWanted(target) then
                stopAllInputs()
                State = "M4_DASH_FOLLOWUP"
                local dashed = performDash(offset.Unit, token, targetRoot, true)
                if not dashed then
                    movementDirection(Vector3.zero)
                    State = "M4_DASH_NOT_CONFIRMED"
                end
            else
                movementDirection(Vector3.zero)
            end
            break
        end
        RunService.Heartbeat:Wait()
    end

    -- The dash is allowed to start immediately, but the next M1 decision
    -- still respects the full M4 recovery window.
    local remainingRecovery = CONFIG.M4Recovery - (os.clock() - startedAt)
    if remainingRecovery > 0
        and not waitInterruptible(remainingRecovery, token, target) then
        return finish(false)
    end
    return finish(foundRagdoll)
end

local function m1ChainCore(target, token, finishMode, startStage)
    if not actionStillValid(token, target) then return false end
    if os.clock() < NextM1AllowedAt then return false end
    State = "M1_CHAIN"
    CurrentM1Stage = 0
    local initialRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    if initialRoot then
        movementDirection(combatMovementDirection(initialRoot, "ATTACK"), "ATTACK")
    end
    finishMode = finishMode or resolveFinishMode(target)

    for stage = startStage or 1, 4 do
        if not actionStillValid(token, target) then
            stopAllInputs()
            return false
        end
        local targetRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        if not targetRoot or not canAttack(targetRoot, CONFIG.M1BreakRange) then
            if target.Character and isRagdolled(target.Character) then
                State = "M1_ABORT_TARGET_RAGDOLL"
            elseif target.Character and hasGetupIFrames(target.Character) then
                State = "M1_ABORT_TARGET_IFRAMES"
            else
                State = "M1_ABORT_TARGET_RANGE"
            end
            stopAllInputs()
            return false
        end

        faceTarget(targetRoot, true)
        movementDirection(combatMovementDirection(targetRoot, "ATTACK"), "ATTACK")
        if targetBlockIsActive() and not isBehindTarget(targetRoot) then
            State = "M1_ABORT_TARGET_BLOCK"
            stopAttackInputs()
            return false
        end
        -- R3 hook: M3 hit bookkeeping / M4 route choice
        if stage == 3 then
            RF.markM3(target)
        elseif stage == 4 then
            local route = RF.chooseFinishRoute(target, token, finishMode)
            if route == "LWS_AFTER_M3" then
                return RF.routeLWSAfterM3(target, token)
            elseif route == "FW_AFTER_M3" then
                return RF.routeFWAfterM3(target, token)
            elseif route == "UPPER_AIR" then
                finishMode = "UPPERCUT"
                RS.FinishPlan = "AIR"
            elseif route == "NEUTRAL_CATCH" then
                finishMode = "NEUTRAL"
                RS.FinishPlan = "CATCH"
            end
        end
        local previousSerial = OwnM1Serial
        local special = stage == 4 and finishMode ~= "NEUTRAL"
        if stage == 4 then
            M4FollowupActive = true
        end
        if special then
            sendKey(Enum.KeyCode.Space, true)
            if finishMode == "DOWNSLAM" and not waitInterruptible(0.08, token, target) then
                M4FollowupActive = false
                stopAllInputs()
                return false
            end
            targetRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            if not targetRoot or not canAttack(targetRoot, CONFIG.M1BreakRange) then
                M4FollowupActive = false
                stopAllInputs()
                return false
            end
            movementDirection(combatMovementDirection(targetRoot, "ATTACK"), "ATTACK")
        end

        if not attackTap() then
            sendKey(Enum.KeyCode.Space, false)
            M4FollowupActive = false
            return false
        end
        task.wait(CONFIG.M1InputGap)
        sendKey(Enum.KeyCode.Space, false)
        NextM1AllowedAt = os.clock() + CONFIG.M1SafetyWait

        local observedId, observedStage, abortReason = waitForOwnM1(
            previousSerial, token, target, stage == 4)
        if not observedId then
            State = abortReason == "TARGET_NOT_ATTACKABLE"
                and "M1_ABORT_TARGET_STATE"
                or "M1_CONFIRM_FAILED"
            M4FollowupActive = false
            stopAllInputs()
            return false
        end

        if stage < 4 and observedStage ~= stage then
            State = "M1_STAGE_DESYNC"
            stopAllInputs()
            return false
        end
        if stage == 4 and observedStage < 4 then
            State = "M1_FINISH_DESYNC"
            M4FollowupActive = false
            stopAllInputs()
            return false
        end
        CurrentM1Stage = observedStage
        if stage == 3 then
            RS.M3ObservedAt = os.clock()
            RS.M3Id = observedId
        end

        -- R3 hook: planned finisher follow-up replaces the M4 recovery wait
        if stage == 4 and RS.FinishPlan then
            local plan = RS.FinishPlan
            RS.FinishPlan = nil
            local ok, result = pcall(plan == "AIR" and RF.airCatch or RF.ragdollCatch, target, token)
            M4FollowupActive = false
            if not ok then error(result, 0) end
            return result
        end

        if stage == 4 then
            State = "M4_RECOVERY"
            local completed = waitForM4DashFollowup(target, token)
            if completed and CONFIG.EnableBackdashReset and actionStillValid(token, target) then
                local remainingRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
                if remainingRoot and not isRagdolled(target.Character)
                    and distanceTo(target.Character) <= 5 then
                    faceTarget(remainingRoot, true)
                    local away = flat(Root.Position - remainingRoot.Position)
                    if away.Magnitude > 0.05
                        and RF.offensiveDashAllowed(classifyDashDirection(away.Unit), target) then
                        performDash(away.Unit, token)
                    end
                end
            end
            return completed
        end
        if not waitInterruptible(CONFIG.M1InputGap, token, target) then
            stopAllInputs()
            return false
        end
    end
    return true
end

local function m1Chain(target, token, finishMode, startStage)
    RS.ChainLive = true
    if (startStage or 1) > 3 then RS.M3ObservedAt = 0 end -- no stale M3 hit data
    local ok, result = pcall(m1ChainCore, target, token, finishMode, startStage)
    RS.ChainLive = false
    RS.M1MinOverride = nil
    RS.FinishPlan = nil
    M4FollowupActive = false
    if not ok then error(result, 0) end
    return result
end

-- ===================== R2: moves + verify =====================
function RF.onOwnAnimation(id, now)
    if DASH_IDS[id] or M1_IDS[id] or UPPERCUT_IDS[id] or DOWNSLAM_IDS[id]
        or RS.IgnoreIds[id] then
        return
    end
    RS.LastOwnMove = {id = id, at = now}
end

function RF.moveReady(slot)
    local move = RS.Moves[slot]
    return CONFIG.MovesEnabled and move ~= nil and os.clock() >= move.readyAt
end

function RF.idOwnedByOtherSlot(id, slot)
    for otherSlot, move in pairs(RS.Moves) do
        if otherSlot ~= slot and move.ids[id] then return true end
    end
    return false
end

function RF.tapKey(key)
    sendKey(key, true)
    task.wait()
    sendKey(key, false)
end

function RF.toolEquipped()
    return Character ~= nil and Character:FindFirstChildOfClass("Tool") ~= nil
end

-- R6 press flow: slot key selects the tool, a short delay lets the server
-- equip it, the screen click (attack button) activates it, our own animation
-- confirms it, a short delay lets the server register it, then unselect.
-- No tool / no animation = we were stunned or dead: retry later, never
-- treated as a cooldown problem.
function RF.pressMove(slot, token)
    RS.MoveInProgress = true
    local ok, result = pcall(RF.pressMoveCore, slot, token)
    RS.MoveInProgress = false
    RS.MoveEndedAt = os.clock()
    if not ok then error(result, 0) end
    return result
end

-- MOBILE unselect: tap the slot again; if the tool is still held, unequip it
-- externally (Humanoid:UnequipTools), since there are no keys to rely on.
function RF.unselectMove(move)
    if not RF.toolEquipped() then return end
    RF.tapKey(move.key)
    task.wait(0.1)
    if RF.toolEquipped() and Humanoid then
        pcall(function() Humanoid:UnequipTools() end)
    end
end

function RF.pressMoveCore(slot, token)
    local move = RS.Moves[slot]
    if not RF.moveReady(slot) or RF.threatLockActive() then return false end
    local function fail(reason)
        move.readyAt = os.clock() + CONFIG.MoveRetryDelay
        State = "MOVE_" .. move.name .. "_" .. reason
        return false
    end

    RF.tapKey(move.key)
    if not waitInterruptible(CONFIG.MoveSelectDelay, token) then
        if RF.toolEquipped() then RF.tapKey(move.key) end
        return fail("INTERRUPTED")
    end
    if CONFIG.MoveRequireTool and not RF.toolEquipped() then
        return fail("NO_TOOL")
    end

    local pressedAt = os.clock()
    attackTap()

    local confirmed = false
    while os.clock() - pressedAt < CONFIG.MoveVerifyWindow do
        local last = RS.LastOwnMove
        if last and last.at >= pressedAt then
            if move.ids[last.id] then
                confirmed = true
            elseif not RF.idOwnedByOtherSlot(last.id, slot) then
                move.ids[last.id] = true -- auto-learn this slot's animation
                confirmed = true
            end
            if confirmed then break end
        end
        if token and token ~= ActionGeneration then break end
        RunService.Heartbeat:Wait()
    end

    task.wait(CONFIG.MoveUnselectDelay)
    RF.unselectMove(move)

    if not confirmed then return fail("NOT_CONFIRMED") end
    move.lastUsedAt = pressedAt
    move.readyAt = pressedAt + move.cooldown
    State = "MOVE_" .. move.name
    return true
end

-- ===================== R2: techs =====================
-- Side dash without waiting for the dash to end, so the next input (M1 or a
-- move) lands during the dash. Cooldown bookkeeping follows the dash track.
function RF.quickSideDash(direction, token)
    local kind = classifyDashDirection(direction)
    if kind ~= "LEFT" and kind ~= "RIGHT" then return false end
    if not dashCooldownReady(kind) then return false end
    local previousSerial = OwnDashSerial
    movementDirection(direction, "DASH_ALIGN")
    if not waitInterruptible(0.035, token) then return false end
    ActiveOwnDashKind = kind
    RF.tapKey(Enum.KeyCode.Q)
    task.spawn(function()
        local started = os.clock()
        while os.clock() - started < CONFIG.DashStartTimeout do
            if OwnDashSerial > previousSerial then
                LastSideDash = os.clock()
                LastOwnDashKind = kind
                break
            end
            RunService.Heartbeat:Wait()
        end
        local track = ActiveDashTrack
        while track and track.IsPlaying and os.clock() - started < CONFIG.DashTimeout do
            RunService.Heartbeat:Wait()
        end
        LastOwnDashEndedAt = os.clock()
        ActiveOwnDashKind = nil
    end)
    return true
end

function RF.techSideDirection(targetRoot)
    local camera = workspace.CurrentCamera
    local right = unitOr(flat(camera and camera.CFrame.RightVector or Root.CFrame.RightVector),
        Vector3.new(1, 0, 0))
    local sign = math.random() < 0.5 and 1 or -1
    return right * RF.teamStrafeSign(sign, right)
end

-- TECH: close side dash around them, M1 on the dash key, keep facing their
-- back while the dash carries us around, then continue the string.
function RF.techSideDashM1(target, token)
    local targetRoot = RF.rootOf(target)
    if not targetRoot then return false end
    faceTarget(targetRoot, true)
    local previousM1 = OwnM1Serial
    State = "TECH_SIDEDASH_M1"
    if not RF.quickSideDash(RF.techSideDirection(targetRoot), token) then return false end
    faceTarget(targetRoot, true)
    attackTap()
    movementDirection(Vector3.zero)

    local started = os.clock()
    local observedStage
    while os.clock() - started < 0.5 do
        if not actionStillValid(token, target) then return false end
        targetRoot = RF.rootOf(target)
        if not targetRoot then return false end
        faceTarget(targetRoot, true)
        if OwnM1Serial > previousM1 then
            observedStage = OwnM1Stage
            break
        end
        RunService.Heartbeat:Wait()
    end
    if not observedStage then
        State = "TECH_M1_NOT_CONFIRMED"
        return false
    end
    if observedStage >= 4 then return true end
    RS.M1MinOverride = CONFIG.TechM1MinRange
    return m1Chain(target, token, nil, observedStage + 1)
end

-- TECH: block break. Close side dash, then Flowing Water on the dash.
function RF.techFlowingWaterBreak(target, token)
    if not RF.moveReady(1) then return false end
    local targetRoot = RF.rootOf(target)
    if not targetRoot then return false end
    faceTarget(targetRoot, true)
    State = "TECH_FW_BREAK"
    local side = RF.techSideDirection(targetRoot)
    local sideKind = classifyDashDirection(side)
    if dashCooldownReady(sideKind) and RF.offensiveDashAllowed(sideKind, target) then
        RF.quickSideDash(side, token)
    end
    targetRoot = RF.rootOf(target)
    if not targetRoot or not actionStillValid(token, target) then return false end
    faceTarget(targetRoot, true)
    movementDirection(Vector3.zero)
    return RF.pressMove(1, token)
end

-- R11: a ragdolled target is only grabbable once it has LANDED: down for a
-- moment, near the ground, not falling, not still sliding from the M4.
function RF.targetSettled(target)
    local character = target and target.Character
    local targetRoot = RF.rootOf(target)
    if not targetRoot or not isRagdolled(character) then return false end
    local since = RS.TargetRagdollSince
    if target == CurrentTarget and (not since or os.clock() - since < CONFIG.HGMinRagdollTime) then
        return false
    end
    local velocity = targetRoot.AssemblyLinearVelocity
    return RF.heightAboveGround(targetRoot, character) <= CONFIG.HGMaxHeight
        and math.abs(velocity.Y) <= CONFIG.HGMaxVerticalSpeed
        and flat(velocity).Magnitude <= CONFIG.HGMaxSlideSpeed
end

-- R12: while HG is ready, a ragdolled target is walked up to (no dash), so
-- the bot arrives as they settle instead of grabbing mid-knockback.
function RF.hgWalkupWanted(target)
    target = target or CurrentTarget
    return CONFIG.HGWalkup and CONFIG.TechsEnabled and RF.moveReady(3)
        and target ~= nil and target.Character ~= nil and isRagdolled(target.Character)
end

-- TECH: Hunter's Grasp picks up a ragdolled target.
function RF.techHunterGrasp(target, token)
    if not RF.moveReady(3) then return false end
    local character = target.Character
    local targetRoot = RF.rootOf(target)
    if not targetRoot or not isRagdolled(character) then return false end
    if not RF.targetSettled(target) then return false end
    if flat(targetRoot.Position - Root.Position).Magnitude > CONFIG.HGRange then return false end
    faceTarget(targetRoot, true)
    movementDirection(Vector3.zero)
    State = "TECH_HG_PICKUP"
    return RF.pressMove(3, token)
end

-- Neutral entry at M1 range. Returns true when a tech was attempted (the
-- plain chain is skipped this tick either way).
function RF.tryOffenseTech(target, token)
    if not CONFIG.TechsEnabled or RS.ChainLive then return false end
    local targetRoot = RF.rootOf(target)
    if not targetRoot or not targetCanReceiveM1(target.Character) then return false end
    if RF.threatLockActive() or RF.friendlyInAttackCone(targetRoot) then return false end
    if os.clock() < NextM1AllowedAt then return false end
    local distance = flat(targetRoot.Position - Root.Position).Magnitude
    if distance < CONFIG.TechCloseMin or distance > CONFIG.TechCloseMax then return false end
    if not RF.aimedAtUs(targetRoot) or math.random() >= CONFIG.TechSideDashM1Chance then
        return false
    end
    if not dashCooldownReady("LEFT") or not RF.offensiveDashAllowed("LEFT", target) then
        return false
    end
    RF.techSideDashM1(target, token)
    return true
end

-- Target guarding in front of us. nil = no tech available (orbit instead).
function RF.tryBlockBreak(target, token)
    if not CONFIG.TechsEnabled or RS.ChainLive then return nil end
    local targetRoot = RF.rootOf(target)
    if not targetRoot or isBehindTarget(targetRoot) or RF.threatLockActive() then return nil end
    if RF.friendlyInAttackCone(targetRoot) then return nil end
    local distance = flat(targetRoot.Position - Root.Position).Magnitude
    if distance <= CONFIG.FWBreakRange and RF.moveReady(1) then
        return RF.techFlowingWaterBreak(target, token)
    end
    if distance >= CONFIG.TechCloseMin and distance <= CONFIG.TechCloseMax
        and dashCooldownReady("LEFT") and RF.offensiveDashAllowed("LEFT", target)
        and os.clock() >= NextM1AllowedAt then
        return RF.techSideDashM1(target, token)
    end
    return nil
end

-- ===================== R3: M3 finish routes =====================
function RF.targetHumanoid(target)
    return target and target.Character and target.Character:FindFirstChildOfClass("Humanoid")
end

function RF.markM3(target)
    local h = RF.targetHumanoid(target)
    RS.M3Health = h and h.Health or nil
    RS.M3ObservedAt = 0
    RS.M3Id = nil
end

function RF.heightAboveGround(root, character)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {character, Character}
    local result = workspace:Raycast(root.Position, Vector3.new(0, -60, 0), params)
    return result and (root.Position.Y - result.Position.Y) or 60
end

-- True when M3 took health off and they are not guarding: they are stunned.
-- Only waits when a route is actually possible, so plain MK.1 timing is
-- untouched when every move is cooling.
function RF.waitM3Hit(target, token)
    local h = RF.targetHumanoid(target)
    if not h or not RS.M3Health or RS.M3ObservedAt <= 0 then return false end
    local hitDelay = (RS.M3Id and M1_TIMINGS[RS.M3Id] or 0.22) + 0.05
    local deadline = RS.M3ObservedAt + math.min(hitDelay, CONFIG.M3HitWaitMax)
    while os.clock() < deadline do
        if h.Health < RS.M3Health - 0.5 then break end
        if not actionStillValid(token, target) then return false end
        RunService.Heartbeat:Wait()
    end
    return h.Health < RS.M3Health - 0.5 and not targetBlockIsActive()
end

function RF.chooseFinishRoute(target, token, finishMode)
    RS.FinishPlan = nil
    if not CONFIG.FinishRoutesEnabled or not CONFIG.TechsEnabled or not CONFIG.MovesEnabled then
        return nil
    end
    local lws, fw = RF.moveReady(2), RF.moveReady(1)
    if not lws and not fw then return nil end
    if not RF.waitM3Hit(target, token) then return nil end

    local options, total = {}, 0
    local function add(route, weight)
        if weight > 0 then
            table.insert(options, {route, weight})
            total += weight
        end
    end
    if lws then
        add("LWS_AFTER_M3", CONFIG.RouteWeightLWSAfterM3)
        if finishMode ~= "DOWNSLAM" and CONFIG.EnableUppercut then
            add("UPPER_AIR", CONFIG.RouteWeightUpperAir)
        end
    end
    if fw then add("FW_AFTER_M3", CONFIG.RouteWeightFWAfterM3) end -- R14
    if lws or fw then add("NEUTRAL_CATCH", CONFIG.RouteWeightNeutralCatch) end -- R12: no M4 -> HG
    if total <= 0 then return nil end
    local roll = math.random() * total
    for _, option in ipairs(options) do
        roll -= option[2]
        if roll <= 0 then
            State = "ROUTE_" .. option[1]
            return option[1]
        end
    end
    return options[#options][1]
end

-- ROUTE A: M3 landed, they are stunned: Lethal Whirlwind Stream instead of M4.
function RF.routeLWSAfterM3(target, token)
    local targetRoot = RF.rootOf(target)
    if not targetRoot then return false end
    faceTarget(targetRoot, true)
    movementDirection(Vector3.zero)
    State = "ROUTE_LWS_AFTER_M3"
    return RF.pressMove(2, token)
end

-- ROUTE D (R14): M3 landed, they are stunned: Flowing Water instead of M4.
function RF.routeFWAfterM3(target, token)
    local targetRoot = RF.rootOf(target)
    if not targetRoot then return false end
    faceTarget(targetRoot, true)
    movementDirection(Vector3.zero)
    State = "ROUTE_FW_AFTER_M3"
    return RF.pressMove(1, token)
end

-- Any-direction dash without waiting for it to end.
function RF.quickDash(direction, token)
    local kind = classifyDashDirection(direction)
    if not dashCooldownReady(kind) then return false end
    local previousSerial = OwnDashSerial
    movementDirection(direction, "DASH_ALIGN")
    if not waitInterruptible(0.035, token) then return false end
    ActiveOwnDashKind = kind
    RF.tapKey(Enum.KeyCode.Q)
    task.spawn(function()
        local started = os.clock()
        while os.clock() - started < CONFIG.DashStartTimeout do
            if OwnDashSerial > previousSerial then
                if kind == "LEFT" or kind == "RIGHT" then
                    LastSideDash = os.clock()
                else
                    LastFrontBackDash = os.clock()
                end
                LastOwnDashKind = kind
                break
            end
            RunService.Heartbeat:Wait()
        end
        local track = ActiveDashTrack
        while track and track.IsPlaying and os.clock() - started < CONFIG.DashTimeout do
            RunService.Heartbeat:Wait()
        end
        LastOwnDashEndedAt = os.clock()
        ActiveOwnDashKind = nil
    end)
    return true
end

-- ROUTE B: after the uppercut, stay under them and fire LWS on the way down.
function RF.airCatch(target, token)
    State = "AIR_CATCH_WAIT"
    local deadline = os.clock() + CONFIG.AirCatchTimeout
    local sawRise = false
    while os.clock() < deadline do
        if not actionStillValid(token, target) then return false end
        local targetRoot = RF.rootOf(target)
        if not targetRoot then return false end
        local vy = targetRoot.AssemblyLinearVelocity.Y
        local height = RF.heightAboveGround(targetRoot, target.Character)
        if vy > 2 or height > 4 then sawRise = true end
        local offset = flat(targetRoot.Position - Root.Position)
        faceTarget(targetRoot, true)
        movementDirection(offset.Magnitude > 3 and offset.Unit or Vector3.zero, "AIR_CATCH")
        if sawRise and vy < -CONFIG.AirCatchFallSpeed
            and height <= CONFIG.AirCatchHeight
            and offset.Magnitude <= CONFIG.AirCatchRange then
            movementDirection(Vector3.zero)
            State = "AIR_CATCH_LWS"
            return RF.pressMove(2, token)
        end
        if sawRise and vy <= 0 and height <= 3.2 then
            State = "AIR_CATCH_MISSED_LANDED"
            return false
        end
        RunService.Heartbeat:Wait()
    end
    State = "AIR_CATCH_TIMEOUT"
    return false
end

-- Ballistic landing estimate for a ragdolled target (flat velocity carried).
function RF.predictLanding(targetRoot, character)
    local height = math.max(0, RF.heightAboveGround(targetRoot, character) - 1)
    local vy = targetRoot.AssemblyLinearVelocity.Y
    local g = workspace.Gravity
    local t = (vy + math.sqrt(math.max(0, vy * vy + 2 * g * height))) / g
    t = math.clamp(t, 0, 1.2)
    return targetRoot.Position + flat(targetRoot.AssemblyLinearVelocity) * t, t
end

-- ROUTE C: neutral M4 sends them forward ragdolled. Dash to where they
-- will land and catch on landing: HG (easiest) > LWS > FW.
function RF.ragdollCatch(target, token)
    State = "RAGDOLL_CATCH_WAIT"
    local waitUntil = os.clock() + 0.35
    while not isRagdolled(target.Character) do
        if os.clock() > waitUntil or not actionStillValid(token, target) then return false end
        RunService.Heartbeat:Wait()
    end
    local targetRoot = RF.rootOf(target)
    if not targetRoot then return false end
    local landing, airTime = RF.predictLanding(targetRoot, target.Character)
    local toLanding = flat(landing - Root.Position)
    if toLanding.Magnitude > CONFIG.RagdollCatchRange then
        faceTarget(targetRoot, true)
        State = "RAGDOLL_CATCH_DASH"
        RF.quickDash(toLanding.Unit, token) -- ragdolled target: reserve exempt
    end

    local catchStarted = os.clock()
    local deadline = os.clock() + airTime + 0.6
    while os.clock() < deadline do
        if not actionStillValid(token, target) then return false end
        targetRoot = RF.rootOf(target)
        if not targetRoot then return false end
        landing = RF.predictLanding(targetRoot, target.Character)
        faceTarget(targetRoot, true)
        local toTarget = flat(targetRoot.Position - Root.Position)
        local toSpot = flat(landing - Root.Position)
        if not ownDashIsActive() then
            movementDirection(toSpot.Magnitude > 2 and toSpot.Unit or Vector3.zero, "RAGDOLL_CATCH")
        end
        local height = RF.heightAboveGround(targetRoot, target.Character)
        local vy = targetRoot.AssemblyLinearVelocity.Y
        local landed = os.clock() - catchStarted >= 0.25
            and height <= CONFIG.RagdollCatchHeight and math.abs(vy) <= CONFIG.HGMaxVerticalSpeed
        if landed and toTarget.Magnitude <= CONFIG.RagdollCatchRange then
            movementDirection(Vector3.zero)
            if RF.moveReady(2) and toTarget.Magnitude <= CONFIG.LWSRange then
                State = "RAGDOLL_CATCH_LWS"
                return RF.pressMove(2, token)
            elseif RF.moveReady(1) then
                State = "RAGDOLL_CATCH_FW"
                return RF.pressMove(1, token)
            end
            return false
        end
        RunService.Heartbeat:Wait()
    end
    State = "RAGDOLL_CATCH_TIMEOUT"
    return false
end

local function approach(target, token)
    if not actionStillValid(token, target) then return false end
    local targetRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return false end
    local offset = flat(targetRoot.Position - Root.Position)
    local distance = offset.Magnitude
    if distance < CONFIG.M1MinRange then
        State = "SPACING_OUT"
        local away = unitOr(flat(Root.Position - targetRoot.Position),
            -flat(targetRoot.CFrame.LookVector))
        faceTarget(targetRoot, true)
        movementDirection(away, "SPACING")
        return false
    end
    if distance <= CONFIG.M1CommitRange then
        faceTarget(targetRoot, true)
        if os.clock() < RS.TargetBlockEndedAt + RS.BlockDropWindow then
            State = "BLOCK_DROP_READ"
            movementDirection(combatMovementDirection(targetRoot, "RECOVERY"), "BLOCK_DROP_READ")
            return false
        end
        if os.clock() < NextM1AllowedAt then
            State = "M1_COOLDOWN"
            movementDirection(
                combatMovementDirection(targetRoot, "ATTACK"),
                "M1_COOLDOWN")
            return false
        end
        if os.clock() - RS.TargetBlockEndedAt < 1.0 then
            RS.ReentryAt = os.clock() -- feeds the adaptive read window
        end
        return true
    end

    State = "APPROACHING"
    local approachDashKind = classifyDashDirection(offset.Unit)
    if not RS.ApproachDashRoll then
        RS.ApproachDashRoll = CONFIG.ApproachDashJitter
            and (CONFIG.ApproachDashMinRange + 2
                + math.random() * (CONFIG.ApproachDashMaxRange - CONFIG.ApproachDashMinRange - 2))
            or CONFIG.ApproachDashMaxRange
    end
    if distance >= CONFIG.ApproachDashMinRange
        and distance <= RS.ApproachDashRoll
        and dashCooldownReady(approachDashKind)
        and RF.offensiveDashAllowed(approachDashKind, target) then
        stopAllInputs()
        faceTarget(targetRoot, true)
        State = "APPROACH_DASH"
        RS.ApproachDashRoll = nil
        if performDash(offset.Unit, token, targetRoot, true) then
            return false
        end
    end

    -- R1 team pincer: when an ally is on this enemy, close in on the far
    -- side so the enemy cannot face both of us.
    local role = RF.teamRole()
    local pincerRange = role == "FLANK" and CONFIG.FlankStartRange or CONFIG.PincerStartRange
    if role and role ~= "FRONT" and distance <= pincerRange then
        local allyRoot = RF.allyRootEngagedWith(target)
        if allyRoot then
            local across = flat(targetRoot.Position - allyRoot.Position)
            local runVelocity = flat(targetRoot.AssemblyLinearVelocity)
            if across.Magnitude > 0.5 then
                local pincer = targetRoot.Position + across.Unit * CONFIG.PincerOffset
                -- flanker cuts off a target running from the front bot
                if role == "FLANK" and runVelocity.Magnitude > 6 then
                    pincer = targetRoot.Position + runVelocity.Unit * CONFIG.CutOffLead
                end
                local toPincer = flat(pincer - Root.Position)
                if toPincer.Magnitude > 1.5 then
                    faceTarget(targetRoot, true)
                    State = "APPROACH_PINCER"
                    movementDirection(RF.applyFriendSeparation(toPincer.Unit), "PINCER")
                    return false
                end
            end
        end
    end

    -- Keep the approach decisive: face the target directly and hold one
    -- meaningful movement intent instead of blending into micro-corrections.
    faceTarget(targetRoot, true)
    movementDirection(RF.applyFriendSeparation(offset.Unit), "APPROACH")
    return false
end

local function ragdollChase(target, token)
    if not actionStillValid(token, target) then return false end
    local targetRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return false end
    State = "RAGDOLL_CHASE"

    local predicted = targetRoot.Position
        + flat(targetRoot.AssemblyLinearVelocity) * CONFIG.RagdollPrediction
    local offset = flat(predicted - Root.Position)
    if offset.Magnitude < CONFIG.M1MinRange then
        State = "RAGDOLL_SPACING"
        local away = unitOr(flat(Root.Position - targetRoot.Position),
            -flat(targetRoot.CFrame.LookVector))
        movementDirection(away, "SPACING")
        if not waitInterruptible(0.08, token, target) then
            movementDirection(Vector3.zero)
            return false
        end
        movementDirection(Vector3.zero)
    elseif offset.Magnitude > CONFIG.M1Range then
        faceTarget(targetRoot, true)
        if not performDash(offset.Unit, token, targetRoot, true) then
            movementDirection(offset.Unit, "CHASE")
            if not waitInterruptible(0.18, token, target) then
                movementDirection(Vector3.zero)
                return false
            end
            movementDirection(Vector3.zero)
        end
    elseif offset.Magnitude > CONFIG.M1CommitRange then
        movementDirection(offset.Unit, "CHASE")
        if not waitInterruptible(0.08, token, target) then
            movementDirection(Vector3.zero)
            return false
        end
        movementDirection(Vector3.zero)
    end
    if not actionStillValid(token, target) then return false end

    targetRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    if targetRoot and canAttack(targetRoot, CONFIG.M1CommitRange) then
        faceTarget(targetRoot, true)
        return m1Chain(target, token, "NEUTRAL")
    end
    return false
end

local function blockCircleAndReenter(target, token)
    if not actionStillValid(token, target) then return false end

    local segmentEnd = os.clock() + CONFIG.BlockCircleMaxTime
    local attemptedSideDash = false

    while os.clock() < segmentEnd do
        if not actionStillValid(token, target) then return false end

        local character = target.Character
        local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
        if not targetRoot then return false end

        if not targetBlockIsActive() then
            -- R1 read window: a block drop is exactly when a swap attack
            -- starts. Wait a beat; any threat in it interrupts this action.
            faceTarget(targetRoot, true)
            movementDirection(combatMovementDirection(targetRoot, "RECOVERY"), "BLOCK_DROP_READ")
            State = "BLOCK_DROP_READ"
            local readUntil = RS.TargetBlockEndedAt + RS.BlockDropWindow
            if os.clock() < readUntil
                and not waitInterruptible(readUntil - os.clock(), token, target) then
                return false
            end
            movementDirection(Vector3.zero)
            targetRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            if targetRoot and canAttack(targetRoot, CONFIG.M1CommitRange) then
                State = "BLOCK_ENDED_REENTER"
                RS.ReentryAt = os.clock()
                local completed = m1Chain(target, token, "NEUTRAL")
                if completed then
                    RS.BlockDropWindow = math.max(CONFIG.BlockDropReadMin,
                        RS.BlockDropWindow - 0.01)
                end
                return completed
            end
            return false
        end

        faceTarget(targetRoot, true)
        local distance = flat(targetRoot.Position - Root.Position).Magnitude
        if isBehindTarget(targetRoot)
            and canAttack(targetRoot, CONFIG.M1CommitRange) then
            State = "BLOCK_BREAK_REENTER"
            return m1Chain(target, token, "NEUTRAL")
        end

        local circleDirection = chooseBlockCircleDirection(targetRoot)
        movementDirection(circleDirection, "BLOCK_CIRCLE")

        if not attemptedSideDash and distance <= CONFIG.BlockCircleDashRange then
            local right = unitOr(flat(targetRoot.CFrame.RightVector), Vector3.new(1, 0, 0))
            local side = right * (circleDirection:Dot(right) >= 0 and 1 or -1)
            local sideKind = classifyDashDirection(side)
            if dashCooldownReady(sideKind) and RF.offensiveDashAllowed(sideKind, target) then
                attemptedSideDash = true
                State = "BLOCK_CIRCLE_DASH"
                performDash(side, token, nil, false)
            end
        end

        if not waitInterruptible(0.06, token, target) then return false end
    end

    if targetBlockIsActive() then
        local targetRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        if targetRoot then
            faceTarget(targetRoot, true)
            movementDirection(chooseBlockCircleDirection(targetRoot), "BLOCK_CIRCLE")
        end
        State = "TARGET_BLOCK_ORBIT"
    end
    return true
end

local function reactToTarget(target, pending, token)
    if not actionStillValid(token, target) then return false end
    local targetRoot = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return false end

    if pending.reaction == "BLOCK_CIRCLE" then
        local broke = RF.tryBlockBreak(target, token)
        if broke ~= nil then return broke end
        return blockCircleAndReenter(target, token)
    end

    if pending.reaction == "RAGDOLL" then
        if RF.hgWalkupWanted(target) then return true end
        return ragdollChase(target, token)
    end

    if pending.reaction == "DASH_BEHIND" then
        State = "REACTION_DASH_BEHIND"
        faceTarget(targetRoot, true)
        local desired = chooseBehindDirection(targetRoot)
        if not performDash(desired, token, targetRoot, true) then
            State = "REACTION_SIDE_STEP"
            movementDirection(desired, "SIDE_STEP")
            waitInterruptible(0.18, token, target)
            movementDirection(Vector3.zero)
        end
        if not actionStillValid(token, target) then return false end
        targetRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        if targetRoot then
            faceTarget(targetRoot, true)
            if canAttack(targetRoot, CONFIG.M1CommitRange) then
                return m1Chain(target, token, "NEUTRAL")
            end
        end
        return true
    end

    if pending.reaction == "INTERRUPT" or pending.reaction == "PUNISH" then
        State = "REACTION_" .. pending.reaction
        faceTarget(targetRoot, true)
        if pending.reaction == "INTERRUPT" then
            NextM1AllowedAt = 0 -- R16: hit now; an unconfirmed tap falls back
            RS.M1MinOverride = CONFIG.TechM1MinRange
        end
        if canAttack(targetRoot, CONFIG.M1CommitRange) then
            return m1Chain(target, token, "NEUTRAL")
        end
        RS.M1MinOverride = nil
        return true
    end

    -- R1: evasive reactions are computed from the attacker (source), which
    -- is the target unless this is an external threat.
    local sourceRoot = pending.source and RF.rootOf(pending.source) or targetRoot
    if not sourceRoot then return false end

    if pending.reaction == "EVADE" then
        State = "REACTION_EVADE"
        faceTarget(sourceRoot, true)
        local side = flat(sourceRoot.CFrame.RightVector)
        if LastTargetPosition and not pending.source
            and flat(sourceRoot.Position - LastTargetPosition):Dot(side) < 0 then
            side = -side
        end
        local relative = flat(Root.Position - sourceRoot.Position)
        if pending.source and relative:Dot(side) < 0 then side = -side end
        -- fallback chain: side dash -> back dash -> block (if allowed) -> step
        local dashed = performDash(side, token)
        if not dashed and actionStillValid(token, target) then
            local back = unitOr(relative, -flat(sourceRoot.CFrame.LookVector))
            State = "REACTION_EVADE_BACK"
            dashed = performDash(back, token)
        end
        if not dashed and actionStillValid(token, target)
            and RF.reactionBlockFallback(target, pending, token) then
            return true
        end
        if dashed then
            if RF.threatLockActive() or pending.source then return true end -- hold, no re-entry
            targetRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            if targetRoot and actionStillValid(token, target) then
                faceTarget(targetRoot, true)
                if canAttack(targetRoot, CONFIG.M1CommitRange) then
                    return m1Chain(target, token, "NEUTRAL")
                end
            end
        else
            State = "REACTION_SIDE_STEP"
            movementDirection(side, "SIDE_STEP")
            waitInterruptible(0.18, token, target)
            movementDirection(Vector3.zero)
        end
        return true
    end

    if pending.reaction == "BACK_DASH" then
        State = "REACTION_BACK_DASH"
        faceTarget(sourceRoot, true)
        local relative = flat(Root.Position - sourceRoot.Position)
        local back = unitOr(relative, -flat(sourceRoot.CFrame.LookVector))
        if not performDash(back, token) and actionStillValid(token, target) then
            local right = unitOr(flat(sourceRoot.CFrame.RightVector), Vector3.new(1, 0, 0))
            local side = right * (relative:Dot(right) >= 0 and 1 or -1)
            if not performDash(side, token) then
                State = "REACTION_BACK_STEP"
                local endAt = os.clock() + 0.35
                while os.clock() < endAt and actionStillValid(token, target) do
                    movementDirection(back, "RETREAT")
                    RunService.Heartbeat:Wait()
                end
                movementDirection(Vector3.zero)
            end
        end
        return true -- the threat lock owns re-entry
    end

    if pending.reaction == "RETREAT_FAR" then
        State = "REACTION_RETREAT"
        local relative = flat(Root.Position - sourceRoot.Position)
        local away = unitOr(relative, -flat(sourceRoot.CFrame.LookVector))
        local detect = pending.rule and pending.rule.detect or CONFIG.LongThreatDistance
        if relative.Magnitude < detect * 0.4 then
            performDash(away, token) -- first burst out of the AoE
        end
        local endAt = os.clock() + 0.35
        while os.clock() < endAt and actionStillValid(token, target) do
            movementDirection(RF.fallbackBias(away), "RETREAT")
            faceTarget(sourceRoot)
            RunService.Heartbeat:Wait()
        end
        movementDirection(Vector3.zero)
        return true -- the threat lock keeps retreating until the track stops
    end

    State = "REACTION_REPOSITION"
    local side = flat(targetRoot.CFrame.RightVector)
    movementDirection(side, "REPOSITION")
    waitInterruptible(0.12, token, target)
    movementDirection(Vector3.zero)
    return true
end

local function CombatPlayerReaction(target, pending, token)
    return reactToTarget(target, pending, token)
end

local function startAction(callback)
    if Busy then return false end
    Busy = true
    local token = ActionGeneration
    local startedAt = os.clock()
    ActionStartedAt = startedAt
    task.spawn(function()
        local ok, err = pcall(callback, token)
        if not ok then
            State = "ACTION_ERROR"
            warn("[TSB M1 Dash AI MK.1 R22] " .. tostring(err))
            stopAllInputs()
        end
        if ActionStartedAt == startedAt then
            ActionStartedAt = 0
        end
        Busy = false
    end)
    return true
end

local function setCharacter(char)
    invalidateAction()
    PendingReaction = nil
    Busy = false
    ActionStartedAt = 0
    stopAllInputs()
    if OwnAnimationConnection then
        OwnAnimationConnection:Disconnect()
        OwnAnimationConnection = nil
    end
    Character = char
    Humanoid = char:WaitForChild("Humanoid", 5)
    Root = char:WaitForChild("HumanoidRootPart", 5)
    Animator = Humanoid and (Humanoid:FindFirstChildOfClass("Animator")
        or Humanoid:WaitForChild("Animator", 2))
    ActiveDashTrack = nil
    ActiveOwnDashKind = nil
    LastOwnDashKind = nil
    LastOwnDashEndedAt = -math.huge
    ActiveOwnM1Track = nil
    OwnTrackSeen = {}
    OwnDashSerial = 0
    OwnM1Serial = 0
    OwnM1Stage = 0
    OwnM1SetIndex = nil
    CurrentM1Stage = 0
    CurrentM1Set = nil
    LastOwnM1Id = nil
    LastOwnM1At = 0
    NextM1AllowedAt = 0
    PendingBlock = nil
    clearTargetBlockState()
    LastBlockCircleReactionAt = -math.huge
    M4FollowupActive = false
    TargetGetupIFrameUntil = 0
    LastOwnRagdolled = false
    OwnRagdollEscapeTried = false
    OwnRagdollEscapeSucceeded = false
    OwnRagdollEscapeRetryAt = 0
    OwnRagdollRecoveryUntil = 0
    OwnRagdollEscapeKind = nil
    RS.ThreatWatches = {}
    RS.ThreatLock = nil
    RS.ChainLive = false
    RS.BlockMaxHold = nil
    RS.ApproachDashRoll = nil
    RS.TargetBlockEndedAt = -math.huge
    RS.ReentryAt = -math.huge
    if RS.OwnHealthConnection then
        pcall(function() RS.OwnHealthConnection:Disconnect() end)
        RS.OwnHealthConnection = nil
    end
    if RS.DiedConnection then
        pcall(function() RS.DiedConnection:Disconnect() end)
        RS.DiedConnection = nil
    end
    if not Humanoid or not Root or not Animator then return end
    RS.DiedConnection = Humanoid.Died:Connect(function()
        RF.onOwnDeath()
    end)

    -- R1: getting hit right after a block-drop re-entry means that opponent
    -- swaps fast; widen the read window for them.
    RS.LastOwnHealth = Humanoid.Health
    RS.OwnHealthConnection = Humanoid.HealthChanged:Connect(function(health)
        local previous = RS.LastOwnHealth or health
        RS.LastOwnHealth = health
        if health < previous - 0.5
            and os.clock() - RS.ReentryAt <= CONFIG.ReentryPunishWindow then
            RS.BlockDropWindow = math.min(CONFIG.BlockDropReadMax, RS.BlockDropWindow + 0.04)
        end
    end)

    OwnAnimationConnection = Animator.AnimationPlayed:Connect(function(track)
        local id = animationId(track)
        if not id then return end
        local now = os.clock()
        local position = track.TimePosition or 0
        local previousPosition = OwnTrackSeen[track]
        if previousPosition and now - previousPosition.time < 0.1
            and math.abs(position - previousPosition.position) < 0.05 then
            return
        end
        OwnTrackSeen[track] = {time = now, position = position}
        RF.onOwnAnimation(id, now)

        if DASH_IDS[id] then
            ActiveDashTrack = track
            ActiveDashStarted = now
            OwnDashSerial += 1
            LastOwnAnimationId = id
            LastOwnAnimationAt = now
        end

        local first = tostring(id):sub(1, 1)
        local bucket = M1_BY_FIRST_DIGIT[first]
        local exactM1 = bucket and bucket[id] == true
        if exactM1 or DOWNSLAM_IDS[id] or UPPERCUT_IDS[id] then
            LastOwnAnimationId = id
            LastOwnAnimationAt = now
            OwnM1Serial += 1
            updateOwnM1Observation(id, track)
        end
    end)
end

RS.CharacterAddedConnection = LocalPlayer.CharacterAdded:Connect(setCharacter)
if LocalPlayer.Character then task.spawn(setCharacter, LocalPlayer.Character) end

local gui = Instance.new("ScreenGui")
RS.OurGui = gui
gui.Name = "TSBM1DashAIReactive"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 20
local playerGui = LocalPlayer:WaitForChild("PlayerGui")
local oldGui = playerGui:FindFirstChild(gui.Name)
if oldGui then oldGui:Destroy() end
local oldGuiV1 = playerGui:FindFirstChild("TSBM1DashAIV1")
if oldGuiV1 then oldGuiV1:Destroy() end
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(260, 190)
panel.Position = UDim2.fromOffset(18, 300)
panel.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
panel.BorderColor3 = Color3.fromRGB(120, 120, 120)
panel.Parent = gui

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -10, 0, 114)
status.Position = UDim2.fromOffset(5, 5)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(255, 225, 120)
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.Font = Enum.Font.Code
status.TextSize = 12
status.Parent = panel

local offsetPanel = Instance.new("Frame")
offsetPanel.Name = "MobileTouchOffset"
offsetPanel.AnchorPoint = Vector2.new(1, 0.5)
offsetPanel.Position = UDim2.new(0.82, 0, 0.5, 0)
offsetPanel.Size = UDim2.fromOffset(154, 72)
offsetPanel.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
offsetPanel.BackgroundTransparency = 0.08
offsetPanel.BorderColor3 = Color3.fromRGB(120, 120, 120)
offsetPanel.ZIndex = 90
offsetPanel.Parent = gui

local offsetTitle = Instance.new("TextLabel")
offsetTitle.Name = "Title"
offsetTitle.Size = UDim2.new(1, -8, 0, 18)
offsetTitle.Position = UDim2.fromOffset(4, 2)
offsetTitle.BackgroundTransparency = 1
offsetTitle.Text = "TOUCH Y OFFSET (PX)"
offsetTitle.TextColor3 = Color3.fromRGB(255, 225, 120)
offsetTitle.Font = Enum.Font.Code
offsetTitle.TextSize = 11
offsetTitle.TextXAlignment = Enum.TextXAlignment.Left
offsetTitle.ZIndex = 91
offsetTitle.Parent = offsetPanel

local offsetBox = Instance.new("TextBox")
offsetBox.Name = "OffsetInput"
offsetBox.Size = UDim2.new(1, -8, 0, 27)
offsetBox.Position = UDim2.fromOffset(4, 20)
offsetBox.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
offsetBox.BorderColor3 = Color3.fromRGB(120, 120, 120)
offsetBox.ClearTextOnFocus = false
offsetBox.Text = tostring(RS.MobileYOffsetPx or 0)
offsetBox.PlaceholderText = "positive = up"
offsetBox.TextColor3 = Color3.new(1, 1, 1)
offsetBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
offsetBox.Font = Enum.Font.Code
offsetBox.TextSize = 13
offsetBox.TextXAlignment = Enum.TextXAlignment.Center
offsetBox.ZIndex = 91
offsetBox.Parent = offsetPanel

local offsetStatus = Instance.new("TextLabel")
offsetStatus.Name = "SaveStatus"
offsetStatus.Size = UDim2.new(1, -8, 0, 15)
offsetStatus.Position = UDim2.fromOffset(4, 49)
offsetStatus.BackgroundTransparency = 1
offsetStatus.Text = "+ UP  /  - DOWN"
offsetStatus.TextColor3 = Color3.fromRGB(180, 180, 180)
offsetStatus.Font = Enum.Font.Code
offsetStatus.TextSize = 10
offsetStatus.TextXAlignment = Enum.TextXAlignment.Left
offsetStatus.ZIndex = 91
offsetStatus.Parent = offsetPanel

local touchpointPreviewSpecs = {
    {"Attack", "ATK"}, {"Block", "BLK"}, {"Dash", "DASH"}, {"Jump", "JMP"},
    {"Move1", "1"}, {"Move2", "2"}, {"Move3", "3"}, {"Move4", "4"},
}
local touchpointPreview = {}
for _, spec in ipairs(touchpointPreviewSpecs) do
    local marker = Instance.new("Frame")
    marker.Name = "TouchPreview_" .. spec[1]
    marker.AnchorPoint = Vector2.new(0.5, 0.5)
    marker.Size = UDim2.fromOffset(30, 20)
    marker.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    marker.BackgroundTransparency = 0.12
    marker.BorderColor3 = Color3.fromRGB(255, 220, 80)
    marker.BorderSizePixel = 2
    marker.Active = false
    marker.Visible = false
    marker.ZIndex = 100
    marker.Parent = gui

    local markerText = Instance.new("TextLabel")
    markerText.Size = UDim2.fromScale(1, 1)
    markerText.BackgroundTransparency = 1
    markerText.Text = spec[2]
    markerText.TextColor3 = Color3.new(1, 1, 1)
    markerText.Font = Enum.Font.Code
    markerText.TextSize = 10
    markerText.Active = false
    markerText.ZIndex = 101
    markerText.Parent = marker
    touchpointPreview[spec[1]] = marker
end

local function refreshTouchpointPreview()
    for _, spec in ipairs(touchpointPreviewSpecs) do
        local marker = touchpointPreview[spec[1]]
        local point = RF.mobilePoint(spec[1])
        marker.Position = UDim2.fromOffset(point.X, point.Y)
    end
end

local function setTouchpointPreviewVisible(visible)
    for _, marker in pairs(touchpointPreview) do marker.Visible = visible end
    if visible then
        refreshTouchpointPreview()
        if not RS.MobileOffsetPreviewConnection then
            RS.MobileOffsetPreviewConnection = RunService.RenderStepped:Connect(refreshTouchpointPreview)
        end
    elseif RS.MobileOffsetPreviewConnection then
        RS.MobileOffsetPreviewConnection:Disconnect()
        RS.MobileOffsetPreviewConnection = nil
    end
end

local function validOffsetFromText(value)
    local parsed = tonumber(value)
    if not parsed or parsed ~= parsed or math.abs(parsed) > 10000 then return nil end
    return parsed
end

local function describeOffset(value, prefix)
    if value > 0 then return string.format("%s%.1f PX UP", prefix or "", value) end
    if value < 0 then return string.format("%s%.1f PX DOWN", prefix or "", math.abs(value)) end
    return (prefix or "") .. "0 PX"
end

offsetBox.Focused:Connect(function()
    offsetStatus.Text = "LIVE PREVIEW"
    offsetStatus.TextColor3 = Color3.fromRGB(255, 225, 120)
    offsetBox.BorderColor3 = Color3.fromRGB(255, 220, 80)
    setTouchpointPreviewVisible(true)
end)

offsetBox:GetPropertyChangedSignal("Text"):Connect(function()
    if not offsetBox:IsFocused() then return end
    local parsed = validOffsetFromText(offsetBox.Text)
    if parsed then
        RS.MobileYOffsetPx = parsed
        offsetStatus.Text = describeOffset(parsed, "LIVE: ")
        refreshTouchpointPreview()
    end
end)

offsetBox.FocusLost:Connect(function()
    local parsed = validOffsetFromText(offsetBox.Text)
    if parsed then
        RS.MobileYOffsetPx = parsed
    else
        offsetBox.Text = tostring(RS.MobileYOffsetPx or 0)
    end
    offsetBox.Text = tostring(RS.MobileYOffsetPx or 0)
    setTouchpointPreviewVisible(false)
    offsetBox.BorderColor3 = Color3.fromRGB(120, 120, 120)
    local saved, saveError = RF.saveMobileLayout()
    if saved then
        offsetStatus.Text = "SAVED FOR REJOIN"
        offsetStatus.TextColor3 = Color3.fromRGB(140, 220, 150)
    else
        offsetStatus.Text = "SAVE UNAVAILABLE"
        offsetStatus.TextColor3 = Color3.fromRGB(240, 150, 120)
        if saveError then warn("[TSB AI] touch offset save failed: " .. tostring(saveError)) end
    end
end)

local start = Instance.new("TextButton")
start.Size = UDim2.fromOffset(108, 28)
start.Position = UDim2.fromOffset(6, 154)
start.Text = "START AI"
start.TextColor3 = Color3.new(1, 1, 1)
start.BackgroundColor3 = Color3.fromRGB(35, 110, 55)
start.BorderColor3 = Color3.fromRGB(150, 220, 160)
start.Font = Enum.Font.Code
start.TextSize = 12
start.Parent = panel

local stop = Instance.new("TextButton")
stop.Size = UDim2.fromOffset(108, 28)
stop.Position = UDim2.fromOffset(134, 154)
stop.Text = "STOP AI"
stop.TextColor3 = Color3.new(1, 1, 1)
stop.BackgroundColor3 = Color3.fromRGB(90, 35, 35)
stop.BorderColor3 = Color3.fromRGB(190, 120, 120)
stop.Font = Enum.Font.Code
stop.TextSize = 12
stop.Parent = panel

local dragging = false
local dragStart, panelStart
panel.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        panelStart = panel.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local delta = input.Position - dragStart
    panel.Position = UDim2.fromOffset(panelStart.X.Offset + delta.X, panelStart.Y.Offset + delta.Y)
end)

local function disableAI(removeGui)
    CONFIG.Enabled = false
    invalidateAction()
    PendingReaction = nil
    Busy = false
    ActionStartedAt = 0
    M4FollowupActive = false
    ActiveOwnDashKind = nil
    LastOwnDashKind = nil
    LastOwnDashEndedAt = -math.huge
    LastOwnRagdolled = false
    OwnRagdollEscapeTried = false
    OwnRagdollEscapeSucceeded = false
    OwnRagdollRecoveryUntil = 0
    State = "OFF"
    disconnectTarget()
    CurrentTarget = nil
    RS.ThreatWatches = {}
    RS.ThreatLock = nil
    RS.ChainLive = false
    RS.AllyIntent = {}
    stopAllInputs()
    if removeGui then
        for player in pairs(RS.ExternalConnections) do RF.unbindExternalPlayer(player) end
        if RS.PlayerAddedConnection then RS.PlayerAddedConnection:Disconnect() end
        if RS.PlayerRemovingConnection then RS.PlayerRemovingConnection:Disconnect() end
        if RS.OwnHealthConnection then RS.OwnHealthConnection:Disconnect() end
        if RS.DiedConnection then RS.DiedConnection:Disconnect() end
        if RS.TeleportConnection then RS.TeleportConnection:Disconnect() end
        -- R15: a re-executed copy must not leave this one running
        if RS.HeartbeatConnection then RS.HeartbeatConnection:Disconnect() end
        RS.LeaderboardWatch = false
        RS.ToolWatch = false
        if RS.Spoof then RS.Spoof.active = false end
        if RS.ButtonCacheReset then RS.ButtonCacheReset:Disconnect() end
        if RS.MobileOffsetPreviewConnection then
            RS.MobileOffsetPreviewConnection:Disconnect()
            RS.MobileOffsetPreviewConnection = nil
        end
        pcall(function() RunService:UnbindFromRenderStep("TSBAIMobileControl") end)
        if Humanoid then pcall(function() Humanoid.AutoRotate = true end) end
        for name in pairs(RS.MobileHeld) do RF.mobileTouch(name, Enum.UserInputState.End) end
        RS.MobileHeld = {}
        RS.VirtualKeys = {}
        RS.MobileWatch = false
        if RS.LeaderboardRespawnConnection then RS.LeaderboardRespawnConnection:Disconnect() end
        if RS.CharacterAddedConnection then RS.CharacterAddedConnection:Disconnect() end
        if OwnAnimationConnection then pcall(function() OwnAnimationConnection:Disconnect() end) end
        if gui then gui:Destroy() end
    end
end

for _, player in ipairs(Players:GetPlayers()) do RF.bindExternalPlayer(player) end
RS.PlayerAddedConnection = Players.PlayerAdded:Connect(RF.bindExternalPlayer)
RS.PlayerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
    RF.unbindExternalPlayer(player)
    RS.AllyIntent[player] = nil
end)

_G.__TSBM1DashAICleanup = function()
    disableAI(true)
end

function RF.enableAI()
    if RF.hideLeaderboard then RF.hideLeaderboard() end
    CONFIG.Enabled = true
    PendingReaction = nil
    invalidateAction()
    State = "SEARCHING"
end

start.Activated:Connect(function()
    if CONFIG.StartWithReset then
        task.spawn(RF.resetThenEnable, false)
    else
        RF.enableAI()
    end
end)

stop.Activated:Connect(function()
    disableAI(false)
end)

-- R7 guard: no free enemy, an ally is fighting. Sit behind the ally, far
-- from their enemy, facing it; dodge what the sweep sees; any free enemy
-- (chooseTarget) or an attack on us ends guarding.
function RF.escortHoverTick(now, leader)
    local leaderRoot = RF.rootOf(leader)
    if not leaderRoot then return false end
    RF.scanPlayingTracks(now)
    RF.processThreatWatches(nil)
    if RF.threatLockActive() then
        local lock = RS.ThreatLock
        local sourceRoot = RF.rootOf(lock.player) or leaderRoot
        faceTarget(sourceRoot, true)
        movementDirection(RF.lockMovementDirection(lock, sourceRoot), "THREAT_" .. lock.kind)
        State = "ESCORT_THREAT_" .. lock.kind
        return true
    end
    -- stable slot per escort so two escorts never stack: lower name left
    local side = -1
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and RF.friendRole(player) == "ALLY"
            and not RF.isLeaderPlayer(player)
            and string.lower(player.Name) < string.lower(LocalPlayer.Name) then
            side = 1
        end
    end
    local right = unitOr(flat(leaderRoot.CFrame.RightVector), Vector3.new(1, 0, 0))
    local look = unitOr(flat(leaderRoot.CFrame.LookVector), Vector3.new(0, 0, -1))
    local post = leaderRoot.Position + right * side * CONFIG.EscortHoverSide - look * CONFIG.EscortHoverBack
    local toPost = flat(post - Root.Position)
    turnCamera(look)
    movementDirection(toPost.Magnitude > 3 and RF.applyFriendSeparation(toPost.Unit) or Vector3.zero, "ESCORT")
    State = "ESCORT_HOVER"
    return true
end

function RF.guardTick(now)
    if not RF.teamModeActive() or not Root then return false end
    local escorting = RF.teamRole() == "ESCORT"
    local bestAlly, bestEnemy, bestDistance
    for ally, intent in pairs(RS.AllyIntent) do
        if escorting and not RF.isLeaderPlayer(ally) then continue end
        local aRoot, eRoot = RF.rootOf(ally), intent.engaged and RF.rootOf(intent.engaged)
        if aRoot and eRoot then
            local d = flat(aRoot.Position - Root.Position).Magnitude
            if not bestDistance or d < bestDistance then
                bestAlly, bestEnemy, bestDistance = aRoot, eRoot, d
            end
        end
    end
    if not bestAlly then
        if escorting then return RF.escortHoverTick(now, RF.leaderPlayer()) end
        return false
    end

    RF.scanPlayingTracks(now)
    RF.processThreatWatches(nil)
    if RF.threatLockActive() then
        local lock = RS.ThreatLock
        local sourceRoot = RF.rootOf(lock.player) or bestEnemy
        faceTarget(sourceRoot, true)
        movementDirection(RF.lockMovementDirection(lock, sourceRoot), "THREAT_" .. lock.kind)
        State = "GUARD_THREAT_" .. lock.kind
        return true
    end

    local back = unitOr(flat(bestAlly.Position - bestEnemy.Position), flat(bestAlly.CFrame.LookVector) * -1)
    local post = bestAlly.Position + back * (escorting and CONFIG.EscortGuardDistance or CONFIG.GuardDistance)
    local fromEnemy = flat(post - bestEnemy.Position)
    if fromEnemy.Magnitude < CONFIG.GuardMinEnemyDistance then
        post = bestEnemy.Position + unitOr(fromEnemy, back) * CONFIG.GuardMinEnemyDistance
    end
    local toPost = flat(post - Root.Position)
    faceTarget(bestEnemy, true)
    movementDirection(toPost.Magnitude > 3 and RF.applyFriendSeparation(toPost.Unit) or Vector3.zero, "GUARD")
    State = escorting and "ESCORT_GUARD" or "GUARD"
    return true
end

function RF.movesText()
    local parts = {}
    local now = os.clock()
    for slot = 1, 3 do
        local move = RS.Moves[slot]
        local left = move.readyAt - now
        table.insert(parts, string.format("%s:%s", move.name,
            left <= 0 and "RDY" or string.format("%.0f", left)))
    end
    return table.concat(parts, " ")
end

RS.HeartbeatConnection = RunService.Heartbeat:Connect(function()
    local attackPoint = ATTACK_BUTTON.AbsoluteCenter + ATTACK_BUTTON.InputOffset
    local pointText = string.format("%d,%d", attackPoint.X, attackPoint.Y)
    local targetDistance = 0
    if CurrentTarget and Root and CurrentTarget.Character then
        local rawDistance = distanceTo(CurrentTarget.Character)
        targetDistance = rawDistance < math.huge and math.floor(rawDistance) or -1
    end
    local targetBlockText = targetBlockIsActive() and "BLOCKING" or "OPEN"
    local role = RF.teamRole() or RF.friendRole(LocalPlayer) or "SOLO"
    local focus = 0
    for _, intent in pairs(RS.AllyIntent) do
        if intent.engaged == CurrentTarget or intent.pressuredBy == CurrentTarget then focus += 1 end
    end
    local shownLock = RF.threatLockActive() and RS.ThreatLock
    local lockText = shownLock and (shownLock.kind .. (shownLock.rule.counter and "*CTR" or "")) or "-"
    status.Text = string.format(
        "TSB M1 DASH AI MOBILE M6\nSTATE: %s\nTARGET: %s D:%d M1:%d\nTARGET STATE: %s  LOCK: %s\nTEAM: %s  ALLIES ON TGT: %d\nREAD: %.2fs  PERSIST: %s\nMOVES: %s",
        State, CurrentTarget and CurrentTarget.DisplayName or "none", targetDistance, CurrentM1Stage,
        targetBlockText, lockText, role, focus, RS.BlockDropWindow, CONFIG.PersistStatus, RF.movesText())
    if not CONFIG.Enabled then return end
    -- R7: Died can be missed (custom death handling); health at 0 counts too
    local liveHumanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if liveHumanoid and liveHumanoid.Health <= 0 then RF.onOwnDeath() end
    if not getCharacterParts() then State = "WAITING_FOR_CHARACTER" return end

    if Busy and ActionStartedAt > 0 and os.clock() - ActionStartedAt > CONFIG.ActionTimeout then
        invalidateAction()
        stopAllInputs()
        Busy = false
        ActionStartedAt = 0
        State = "ACTION_TIMEOUT"
    end

    local now = os.clock()
    local ownRagdolled = isRagdolled(Character)
    if ownRagdolled and not LastOwnRagdolled then
        OwnRagdollEscapeTried = false
        OwnRagdollEscapeSucceeded = false
        OwnRagdollEscapeRetryAt = now
        OwnRagdollRecoveryUntil = 0
        invalidateAction()
        PendingReaction = nil
        Busy = false
        ActionStartedAt = 0
        stopAllInputs()
    elseif not ownRagdolled and LastOwnRagdolled then
        OwnRagdollRecoveryUntil = math.max(
            OwnRagdollRecoveryUntil,
            now + CONFIG.GetupIFrameTime)
        OwnRagdollEscapeTried = false
    end
    LastOwnRagdolled = ownRagdolled
    RF.commsTick(now)
    RF.updateAllyIntent(now)

    local target = CurrentTarget
    if target and not RS.ChainLive
        and (RF.claimedByAlly(target) or not RF.escortAllows(target)) then
        invalidateAction()
        connectTarget(nil)
        target = nil
        State = "YIELD_TO_ALLY"
    end
    if not validTarget(target) then
        target = chooseTarget()
        if target ~= CurrentTarget then
            invalidateAction()
            connectTarget(target)
        end
        State = target and "TARGET_ACQUIRED" or "SEARCHING"
    elseif CONFIG.TargetMode == "Closest" and not RS.ChainLive then
        local closer = chooseTarget()
        if closer and closer ~= target
            and RF.targetScore(closer) + CONFIG.RetargetIfCloserBy < RF.targetScore(target) then
            target = closer
            invalidateAction()
            connectTarget(target)
            State = "TARGET_SWITCHED"
        end
    end
    if not target then
        if not RF.guardTick(now) then
            stopAllInputs()
        end
        return
    end

    local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end

    local ragdolled = isRagdolled(target.Character)
    if ragdolled then
        RS.TargetRagdollSince = RS.TargetRagdollSince or now
    else
        RS.TargetRagdollSince = nil
    end
    if ragdolled then
        TargetGetupIFrameUntil = 0
    elseif isGettingUpState(target.Character) then
        TargetGetupIFrameUntil = math.max(TargetGetupIFrameUntil,
            now + CONFIG.GetupIFrameTime)
    elseif LastTargetRagdolled then
        TargetGetupIFrameUntil = math.max(TargetGetupIFrameUntil,
            now + CONFIG.GetupIFrameTime)
    end

    refreshTargetBlockState(target)
    RF.scanPlayingTracks(now)
    RF.processThreatWatches(target)
    if target ~= CurrentTarget then
        LastTargetPosition = nil
        return -- a threat retargeted us; rebuild next frame
    end
    if targetBlockIsActive() and not isBehindTarget(targetRoot)
        and not PendingReaction and not Busy then
        queueBlockCircleReaction(target, TargetBlockTrack)
    end

    if processAutoBlock(target, targetRoot) then
        LastTargetPosition = targetRoot.Position
        return
    end

    if ownRagdolled then
        if not Busy and not OwnRagdollEscapeSucceeded
            and now >= OwnRagdollEscapeRetryAt then
            OwnRagdollEscapeTried = true
            startAction(function(actionToken)
                local liveRoot = target.Character
                    and target.Character:FindFirstChild("HumanoidRootPart")
                if not liveRoot then
                    OwnRagdollEscapeTried = false
                    OwnRagdollEscapeRetryAt = os.clock() + CONFIG.OwnRagdollEscapeRetry
                    return
                end
                faceTarget(liveRoot, true)
                State = "OWN_RAGDOLL_EVADE"
                local direction = chooseOwnRagdollEscapeDirection(liveRoot)
                local completed = performDash(direction, actionToken, nil, false)
                if not completed then
                    OwnRagdollEscapeTried = false
                    OwnRagdollEscapeRetryAt = os.clock() + CONFIG.OwnRagdollEscapeRetry
                end
            end)
        end
        State = Busy and "OWN_RAGDOLL_EVADE" or "OWN_RAGDOLL"
        LastTargetPosition = targetRoot.Position
        return
    end

    if now < OwnRagdollRecoveryUntil then
        faceTarget(targetRoot, true)
        movementDirection(
            combatMovementDirection(targetRoot, "RECOVERY"),
            "RECOVERY")
        State = "OWN_RAGDOLL_RECOVERY"
        LastTargetPosition = targetRoot.Position
        return
    end

    if not ragdolled and hasGetupIFrames(target.Character) then
        faceTarget(targetRoot, true)
        movementDirection(
            combatMovementDirection(targetRoot, "RECOVERY"),
            "RECOVERY")
        State = "TARGET_GETUP_IFRAMES"
        LastTargetPosition = targetRoot.Position
        LastTargetRagdolled = false
        return
    end

    if ragdolled and not LastTargetRagdolled then
        RagdollComboDone = false
        NextRagdollTry = 0
        if not M4FollowupActive then
            if not RF.hgWalkupWanted(target) then
                requestReaction(target, "RAGDOLL")
            end
        else
            State = "M4_DASH_FOLLOWUP_PENDING"
        end
    end
    if not ragdolled then
        RagdollComboDone = false
    end
    LastTargetRagdolled = ragdolled

    if PendingReaction and PendingReaction.target ~= target then
        PendingReaction = nil
    end

    if PendingReaction and not Busy then
        local pending = PendingReaction
        PendingReaction = nil
        startAction(function(actionToken)
            CombatPlayerReaction(target, pending, actionToken)
            if actionToken == ActionGeneration then stopAllInputs() end
        end)
        LastTargetPosition = targetRoot.Position
        return
    end

    if Busy then
        LastTargetPosition = targetRoot.Position
        return
    end

    if ragdolled and CONFIG.TechsEnabled and RF.moveReady(3)
        and distanceTo(target.Character) <= CONFIG.HGRange and RF.targetSettled(target) then
        startAction(function(actionToken)
            RF.techHunterGrasp(target, actionToken)
            if actionToken == ActionGeneration then stopAllInputs() end
        end)
        LastTargetPosition = targetRoot.Position
        return
    end

    if ragdolled and RF.hgWalkupWanted(target) then
        local offset = flat(targetRoot.Position - Root.Position)
        faceTarget(targetRoot, true)
        if offset.Magnitude > CONFIG.HGWalkupStop then
            movementDirection(RF.applyFriendSeparation(offset.Unit), "HG_WALKUP")
            State = "HG_WALKUP"
        else
            movementDirection(Vector3.zero)
            State = "HG_WAIT_SETTLE"
        end
        LastTargetPosition = targetRoot.Position
        return
    end

    if ragdolled and not RagdollComboDone and os.clock() >= NextRagdollTry then
        startAction(function(actionToken)
            local completed = ragdollChase(target, actionToken)
            if completed then
                RagdollComboDone = true
            else
                NextRagdollTry = os.clock() + CONFIG.RagdollRecheck
            end
            if actionToken == ActionGeneration then stopAllInputs() end
        end)
        LastTargetPosition = targetRoot.Position
        return
    end

    if ragdolled then
        faceTarget(targetRoot, true)
        movementDirection(
            combatMovementDirection(targetRoot, "RECOVERY"),
            "RECOVERY")
        State = "TARGET_RAGDOLL_ORBIT"
        LastTargetPosition = targetRoot.Position
        return
    end

    -- R1 threat lock: a hold-until-stop move / counter is live. No approach,
    -- no M1; movement follows the rule until the track stops.
    if RF.threatLockActive() then
        local lock = RS.ThreatLock
        local sourceRoot = RF.rootOf(lock.player) or targetRoot
        faceTarget(sourceRoot, true)
        movementDirection(RF.lockMovementDirection(lock, sourceRoot), "THREAT_" .. lock.kind)
        State = "THREAT_LOCK_" .. lock.kind
        LastTargetPosition = targetRoot.Position
        return
    end

    if os.clock() < NextApproachUpdate then
        LastTargetPosition = targetRoot.Position
        return
    end
    NextApproachUpdate = os.clock() + CONFIG.ApproachUpdateInterval

    startAction(function(actionToken)
        if approach(target, actionToken) then
            if not RF.tryOffenseTech(target, actionToken) then
                m1Chain(target, actionToken)
            end
            if actionToken == ActionGeneration then stopAllInputs() end
        end
    end)
    LastTargetPosition = targetRoot.Position
end)

-- ===================== R6: persistence / autostart / rejoin =====================
-- Manual load: arms persistence only; press START yourself.
-- Auto load (queued by a teleport): wait, reset, respawn, AI switches on.
function RF.queueFunction()
    -- same resolution order Infinite Yield uses
    local q = queue_on_teleport
        or (syn and syn.queue_on_teleport)
        or (fluxus and fluxus.queue_on_teleport)
        or queueonteleport
    return type(q) == "function" and q or nil
end

function RF.iyRunning()
    local ok, loaded = pcall(function()
        return (getgenv and getgenv().IY_LOADED) or IY_LOADED
    end)
    return ok and loaded == true
end

-- R13: our own source text, captured now while file access certainly works.
-- Set by the loader (env.TSB_AI_SOURCE) or read from the workspace file.
function RF.ownSource()
    if RS.OwnSource then return RS.OwnSource end
    local env = getgenv and getgenv() or _G
    local source = type(env.TSB_AI_SOURCE) == "string" and env.TSB_AI_SOURCE or nil
    if not source and type(readfile) == "function" then
        local txtName = (CONFIG.ScriptFile:gsub("%.lua$", ".txt"))
        for _, name in ipairs({CONFIG.ScriptFile, txtName}) do
            local ok, text = pcall(readfile, name)
            if ok and type(text) == "string" and #text > 0 then source = text break end
        end
    end
    RS.OwnSource = source
    return source
end

-- R13 queue payload, same shape as Infinite Yield's: one self-contained chunk.
-- With the source embedded nothing has to be read or downloaded after the
-- teleport; the script's own startup waits handle load order.
function RF.embeddedPayload(source)
    local chainIY = CONFIG.ChainInfiniteYield and RF.iyRunning()
    local parts = {
        "local env = getgenv and getgenv() or _G",
        "if env.TSB_AI_LOADER_RAN then return end",
        "env.TSB_AI_LOADER_RAN = true",
        "env.TSB_AI_AUTOSTART = true",
    }
    if chainIY then
        table.insert(parts, string.format(
            "task.spawn(function() pcall(function() loadstring(game:HttpGet(%q))() end) end)",
            CONFIG.InfiniteYieldUrl))
    end
    table.insert(parts, "env.TSB_AI_SOURCE = " .. string.format("%q", source))
    table.insert(parts, "local fn, e = loadstring(env.TSB_AI_SOURCE)")
    table.insert(parts, "if fn then fn() else warn('[TSB AI loader] compile error: ' .. tostring(e)) end")
    return table.concat(parts, "\n")
end

function RF.loaderSource()
    local source = CONFIG.EmbedSourceInQueue and RF.ownSource()
    if source then return RF.embeddedPayload(source) end
    local txtName = (CONFIG.ScriptFile:gsub("%.lua$", ".txt"))
    local chainIY = CONFIG.ChainInfiniteYield and RF.iyRunning()
    return string.format([[
local function log(message) pcall(warn, "[TSB AI loader] " .. message) end
if not game:IsLoaded() then game.Loaded:Wait() end
local Players = game:GetService("Players")
while not Players.LocalPlayer do task.wait() end
local env = getgenv and getgenv() or _G
if env.TSB_AI_LOADER_RAN then return end -- queued more than once: run once
env.TSB_AI_LOADER_RAN = true
if %s then
    task.spawn(function()
        pcall(function() loadstring(game:HttpGet(%q))() end)
    end)
end
env.TSB_AI_AUTOSTART = true
local source
for _, name in ipairs({%q, %q}) do
    local ok, text = pcall(readfile, name)
    if ok and type(text) == "string" and #text > 0 then source = text break end
end
if not source and %q ~= "" then
    local ok, text = pcall(function() return game:HttpGet(%q) end)
    if ok and type(text) == "string" and #text > 0 then source = text end
end
if not source then log("script file not found in workspace: " .. %q) return end
local fn, compileError = loadstring(source)
if not fn then log("compile error: " .. tostring(compileError)) return end
log("loaded, starting")
env.TSB_AI_SOURCE = source
local ok, runError = pcall(fn)
if not ok then log("runtime error: " .. tostring(runError)) end
]], tostring(chainIY), CONFIG.InfiniteYieldUrl, CONFIG.ScriptFile, txtName,
        CONFIG.ScriptUrl, CONFIG.ScriptUrl, CONFIG.ScriptFile)
end

-- R10: executors that keep ONE queued script let the last queue_on_teleport
-- call win, and Infinite Yield queues its own reload on OnTeleport. So we
-- queue on every teleport state and again a moment later (after IY's
-- handler), with a payload that also reloads IY. The loader runs only once
-- per server even when it was queued several times.
function RF.queueNow()
    local queue = RF.queueFunction()
    if not queue then return false end
    RS.QueueCount = (RS.QueueCount or 0) + 1
    if RS.QueueCount > 8 then return true end
    local ok, err = pcall(queue, RF.loaderSource())
    if not ok then warn("[TSB AI] queue_on_teleport failed: " .. tostring(err)) end
    return ok
end

function RF.queueAfterOthers()
    RF.queueNow()
    task.delay(0.05, RF.queueNow)
    task.delay(0.25, RF.queueNow)
end

-- R12 autoexec fallback (executors without queue_on_teleport, e.g. Solara /
-- Xeno, or when the queue is lost): before a rejoin we write a short-lived
-- flag file; the bootstrap placed in the executor's autoexec folder only
-- loads the AI when that flag is fresh and for the same game.
RF.FLAG_FILE = "TSB_AI_autostart.json"
RF.BOOT_FILE = "TSB_AI_autoexec_boot.lua"

function RF.writeAutostartFlag()
    if not CONFIG.AutoexecFallback or type(writefile) ~= "function" then return end
    pcall(function()
        writefile(RF.FLAG_FILE, game:GetService("HttpService"):JSONEncode({
            placeId = game.PlaceId, t = os.time(),
        }))
    end)
end

function RF.bootstrapSource()
    return "-- copy into your executor's autoexec folder\n"
        .. "local ok, raw = pcall(readfile, " .. string.format("%q", RF.FLAG_FILE) .. ")\n"
        .. "if not ok or type(raw) ~= 'string' then return end\n"
        .. "if not game:IsLoaded() then game.Loaded:Wait() end\n"
        .. "local okJ, flag = pcall(function() return game:GetService('HttpService'):JSONDecode(raw) end)\n"
        .. "if not okJ or flag.placeId ~= game.PlaceId or os.time() - (flag.t or 0) > 180 then return end\n"
        .. "pcall(writefile, " .. string.format("%q", RF.FLAG_FILE) .. ", '{}')\n"
        .. "loadstring(" .. string.format("%q", RF.loaderSource()) .. ")()\n"
end

function RF.writeBootstrap()
    if not CONFIG.AutoexecFallback or type(writefile) ~= "function" then return end
    pcall(writefile, RF.BOOT_FILE, RF.bootstrapSource())
end

function RF.scriptFilePresent()
    if type(isfile) ~= "function" then return nil end -- unknown
    local txtName = (CONFIG.ScriptFile:gsub("%.lua$", ".txt"))
    local ok, present = pcall(function() return isfile(CONFIG.ScriptFile) or isfile(txtName) end)
    return ok and present or false
end

function RF.armPersistence()
    if not CONFIG.PersistEnabled then
        CONFIG.PersistStatus = "OFF"
        return false
    end
    RF.writeBootstrap()
    if not RF.queueFunction() then
        CONFIG.PersistStatus = "AUTOEXEC ONLY"
        warn("[TSB AI] executor has no queue_on_teleport: copy " .. RF.BOOT_FILE
            .. " from workspace into your autoexec folder")
        RS.TeleportConnection = LocalPlayer.OnTeleport:Connect(function(teleportState)
            if teleportState ~= Enum.TeleportState.Failed then RF.writeAutostartFlag() end
        end)
        return true
    end
    local present = RF.scriptFilePresent()
    if present == false and CONFIG.ScriptUrl == "" then
        CONFIG.PersistStatus = "NO FILE"
        warn("[TSB AI] " .. CONFIG.ScriptFile .. " not found in the executor workspace: "
            .. "rejoins will not reload the AI")
    else
        CONFIG.PersistStatus = "OK"
    end
    RS.TeleportConnection = LocalPlayer.OnTeleport:Connect(function(teleportState)
        if teleportState ~= Enum.TeleportState.Failed then
            RF.queueAfterOthers()
            RF.writeAutostartFlag()
        end
    end)
    return true
end

function RF.rejoinSameServer()
    if RS.Rejoining then return end
    RS.Rejoining = true
    local TeleportServiceForRejoin = game:GetService("TeleportService")
    State = "REJOINING"
    RF.queueAfterOthers() -- queue before teleporting, not only on OnTeleport
    RF.writeAutostartFlag()
    local TeleportService = game:GetService("TeleportService")
    task.spawn(function()
        for _ = 1, 5 do
            local ok = pcall(function()
                -- same as Infinite Yield's rejoin: alone in the server -> kick + Teleport
                if #Players:GetPlayers() <= 1 then
                    LocalPlayer:Kick("\nRejoining...")
                    task.wait(0.3)
                    TeleportServiceForRejoin:Teleport(game.PlaceId, LocalPlayer)
                else
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
                end
            end)
            if ok then task.wait(8) else task.wait(2) end
        end
        RS.Rejoining = false -- still here after retries
        RS.DeathHandled = false
        warn("[TSB AI] rejoin failed after 5 attempts; AI back on in this server")
        CONFIG.Enabled = true
        State = "REJOIN_FAILED_RESUMED"
    end)
end

function RF.onOwnDeath()
    if RS.SelfResetting or RS.DeathHandled then return end -- our own reset / already handling
    if CONFIG.RejoinOnDeath and CONFIG.Enabled
        and (RS.AutoSession or CONFIG.RejoinManualSessions) then
        RS.DeathHandled = true
        CONFIG.Enabled = false
        stopAllInputs()
        RF.rejoinSameServer()
    end
end

function RF.ensureShiftLock()
    if not CONFIG.AutoShiftLock then return end
    if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then return end
    RF.tapKey(Enum.KeyCode.LeftShift)
    task.wait(0.3)
    if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
        warn("[TSB AI] shift lock did not engage; enable it manually")
    end
end

function RF.waitForNewCharacter(oldCharacter, timeout)
    local started = os.clock()
    while os.clock() - started < timeout do
        local character = LocalPlayer.Character
        if character and character ~= oldCharacter then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 and character:FindFirstChild("HumanoidRootPart") then
                return character
            end
        end
        task.wait(0.1)
    end
    return nil
end

function RF.selfReset(character)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end
    pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Dead) end)
    pcall(function() humanoid.Health = 0 end)
    task.wait(1)
    if humanoid.Parent and humanoid.Health > 0 then
        pcall(function() character:BreakJoints() end)
    end
end

-- R18: temporarily switch to the mobile control scheme. Each touch pulse
-- makes the last input type Touch, so the character that spawns next gets
-- the mobile buttons (the attack button the AI taps). Keyboard input resumes
-- afterwards as usual.
-- Touch only: the executor's touch-tap function if it has one, else a
-- VirtualInputManager touch event. Never a mouse move or mouse click, so
-- the last input stays Touch.
function RF.touchPulse()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local size = camera.ViewportSize
    local x = math.floor(size.X * CONFIG.MobileTouchPoint[1])
    local y = math.floor(size.Y * CONFIG.MobileTouchPoint[2])
    local tap = _G.touchTap or _G.touch_tap or _G.tap or touchTap or touch_tap
    if type(tap) == "function" and pcall(tap, x, y) then return end
    pcall(function()
        VirtualInputManager:SendTouchEvent(0, Enum.UserInputState.Begin, x, y, 0)
        task.wait()
        VirtualInputManager:SendTouchEvent(0, Enum.UserInputState.End, x, y, 0)
    end)
end

-- R20: a real thumbstick drag (touch begin -> moves -> end) in the mobile
-- thumbstick zone. Uses the live thumbstick frame when Roblox's touch GUI
-- exists, else the bottom-left default zone.
function RF.thumbstickCenter()
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local touchGui = playerGui and playerGui:FindFirstChild("TouchGui")
    local controlFrame = touchGui and touchGui:FindFirstChild("TouchControlFrame")
    local frame = controlFrame and (controlFrame:FindFirstChild("ThumbstickFrame")
        or controlFrame:FindFirstChild("DynamicThumbstickFrame"))
    if frame and frame.AbsoluteSize.X > 0 then
        local inset = game:GetService("GuiService"):GetGuiInset()
        local center = frame.AbsolutePosition + frame.AbsoluteSize / 2 + inset
        local radius = math.max(frame.AbsoluteSize.X, frame.AbsoluteSize.Y) / 2
        return math.floor(center.X), math.floor(center.Y), radius
    end
    local camera = workspace.CurrentCamera
    local size = camera and camera.ViewportSize or Vector2.new(1280, 720)
    return math.floor(size.X * CONFIG.ThumbstickPoint[1]), math.floor(size.Y * CONFIG.ThumbstickPoint[2]),
        size.Y * CONFIG.ThumbstickFallbackRadius
end

-- R22: drag fully OUT of the stick circle, then let go out there
-- (no return to center). Direction varies each drag.
function RF.thumbstickDrag()
    local x, y, radius = RF.thumbstickCenter()
    local distance = math.max(radius * CONFIG.ThumbstickOvershoot, CONFIG.ThumbstickDragDistance)
    local angle = math.rad(-90 + (math.random() * 2 - 1) * 60) -- mostly upward, +/-60 deg
    local ex, ey = math.cos(angle) * distance, math.sin(angle) * distance
    local steps = CONFIG.ThumbstickDragSteps
    pcall(function()
        VirtualInputManager:SendTouchEvent(1, Enum.UserInputState.Begin, x, y, 0)
        for step = 1, steps do
            task.wait()
            VirtualInputManager:SendTouchEvent(1, Enum.UserInputState.Change,
                x + math.floor(ex * step / steps), y + math.floor(ey * step / steps), 0)
        end
        task.wait()
        VirtualInputManager:SendTouchEvent(1, Enum.UserInputState.End,
            x + math.floor(ex), y + math.floor(ey), 0)
    end)
end

-- R21: touch tap at a random spot near the middle of the screen.
function RF.randomMiddleTap()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local size = camera.ViewportSize
    local spread = CONFIG.MiddleTapSpread
    local x = math.floor(size.X * (0.5 + (math.random() * 2 - 1) * spread))
    local y = math.floor(size.Y * (0.5 + (math.random() * 2 - 1) * spread))
    pcall(function()
        VirtualInputManager:SendTouchEvent(2, Enum.UserInputState.Begin, x, y, 0)
        task.wait()
        VirtualInputManager:SendTouchEvent(2, Enum.UserInputState.End, x, y, 0)
    end)
end

function RF.ownCharacterDead()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    return not humanoid or humanoid.Health <= 0 or not character:FindFirstChild("HumanoidRootPart")
end

-- R21: nonstop until actually alive: thumbstick drag, random middle tap, repeat.
function RF.deadInputLoop(keepGoing)
    while RF.ownCharacterDead() and (not keepGoing or keepGoing()) do
        RF.thumbstickDrag()
        RF.randomMiddleTap()
        task.wait(CONFIG.DeadInputGap)
    end
end

-- R19: every death, not only our own reset. While dead and until
-- MobileHoldAfterSpawn after the respawn, keep sending touch taps so the new
-- character always spawns with the mobile buttons.
RS.MobileWatch = true
task.spawn(function()
    local wasDead, respawnedAt = false, nil
    while RS.MobileWatch do
        if CONFIG.MobileControlsOnReset and not RF.spoofActive()
            and (CONFIG.Enabled or RS.Starting or RS.DeathHandled or RS.Rejoining) then
            local character = LocalPlayer.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local dead = not humanoid or humanoid.Health <= 0
                or not character:FindFirstChild("HumanoidRootPart")
            if dead then
                wasDead, respawnedAt = true, nil
                RF.deadInputLoop(function() return RS.MobileWatch end) -- R21: until alive
            elseif wasDead then
                respawnedAt = respawnedAt or os.clock()
                RF.touchPulse()
                if os.clock() - respawnedAt >= CONFIG.MobileHoldAfterSpawn then
                    wasDead = false
                end
            end
        end
        task.wait(0.25)
    end
end)

function RF.startMobileScheme()
    if not CONFIG.MobileControlsOnReset or RF.spoofActive() then return function() end end
    local running = true
    task.spawn(function()
        while running do
            local character = LocalPlayer.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if not humanoid or humanoid.Health <= 0 then
                RF.deadInputLoop(function() return running end)
            else
                RF.touchPulse()
            end
            task.wait(0.25)
        end
    end)
    return function() running = false end
end

function RF.mobileSchemeActive()
    local ok, touch = pcall(function()
        return UserInputService.LastInputType == Enum.UserInputType.Touch
    end)
    return ok and touch
end

-- R11: reset -> wait for the respawn (bounded) -> shift lock -> AI on.
function RF.resetThenEnable(isAuto)
    if RS.Starting then return end
    RS.Starting = true
    RS.AutoSession = RS.AutoSession or isAuto
    CONFIG.Enabled = false
    stopAllInputs()
    if isAuto then
        State = "AUTOSTART_WAIT"
        task.wait(CONFIG.AutoStartDelay)
    end
    local character = LocalPlayer.Character
        or LocalPlayer.CharacterAdded:Wait()
    State = "START_RESET"
    RS.SelfResetting = true
    local stopMobile = RF.startMobileScheme()
    RF.touchPulse()
    RF.selfReset(character)
    State = "START_WAIT_RESPAWN"
    if not RF.waitForNewCharacter(character, CONFIG.RespawnTimeout) then
        warn("[TSB AI] no respawn after reset; enabling on the current character")
    end
    task.wait(CONFIG.MobileHoldAfterSpawn)
    stopMobile()
    if CONFIG.MobileControlsOnReset and not RF.spoofActive() and not RF.mobileSchemeActive() then
        warn("[TSB AI] touch input did not register; mobile buttons may be missing")
    end
    task.wait(CONFIG.AutoEnableDelay)
    RS.SelfResetting = false
    RS.DeathHandled = false
    RF.ensureShiftLock()
    RF.enableAI()
    State = isAuto and "AUTOSTARTED" or "STARTED"
    RS.Starting = false
end

function RF.autoStart()
    RF.resetThenEnable(true)
end

-- R17: the game turns the player list back on at respawn, so keep it off:
-- re-hide on every respawn / AI start, plus a 1 s watchdog for late re-enables.
function RF.hideLeaderboard()
    if not CONFIG.HideLeaderboard then return end
    pcall(function()
        local starterGui = game:GetService("StarterGui")
        if starterGui:GetCoreGuiEnabled(Enum.CoreGuiType.PlayerList) then
            starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
        end
    end)
end

if RF.installTouchSpoof() then
    print("[TSB AI mobile] touch input spoof active")
else
    warn("[TSB AI mobile] executor lacks hookmetamethod/checkcaller: using touch events (pointer) instead")
end
RS.ButtonCacheReset = LocalPlayer.CharacterAdded:Connect(function()
    RS.ButtonCache = {}
    RS.ButtonKind = {}
    RF.P.resetCache()
end)

-- ===================== MOBILE: control loop =====================
-- Runs after Roblox's control module each frame, so our Move wins.
RS.AutoRotateTaken = false
RunService:BindToRenderStep("TSBAIMobileControl", Enum.RenderPriority.Character.Value + 1, function()
    local humanoid, root = Humanoid, Root
    if not CONFIG.Enabled or not humanoid or not root or humanoid.Health <= 0 then
        if RS.AutoRotateTaken and humanoid then
            pcall(function() humanoid.AutoRotate = true end)
            RS.AutoRotateTaken = false
        end
        return
    end
    -- identical to the keyboard module: (D - A, 0, S - W), camera-relative
    local keys = RS.VirtualKeys
    local x = (keys[Enum.KeyCode.D] and 1 or 0) - (keys[Enum.KeyCode.A] and 1 or 0)
    local z = (keys[Enum.KeyCode.S] and 1 or 0) - (keys[Enum.KeyCode.W] and 1 or 0)
    humanoid:Move(Vector3.new(x, 0, z), true)
    if CONFIG.EmulateShiftLock and not humanoid.PlatformStand and not isRagdolled(Character) then
        local camera = workspace.CurrentCamera
        local look = camera and flat(camera.CFrame.LookVector)
        if look and look.Magnitude > 0.05 then
            humanoid.AutoRotate = false
            RS.AutoRotateTaken = true
            root.CFrame = CFrame.lookAt(root.Position, root.Position + look.Unit)
        end
    end
end)

-- External tool watchdog: a tool held while no move is in progress gets
-- unequipped after a short grace period.
RS.ToolWatch = true
task.spawn(function()
    local seenAt
    while RS.ToolWatch do
        if CONFIG.Enabled and CONFIG.ToolWatchdog and not RS.MoveInProgress
            and os.clock() - (RS.MoveEndedAt or 0) > CONFIG.ToolUnexpectedGrace
            and RF.toolEquipped() then
            seenAt = seenAt or os.clock()
            if os.clock() - seenAt >= CONFIG.ToolUnexpectedGrace and Humanoid then
                pcall(function() Humanoid:UnequipTools() end)
                seenAt = nil
            end
        else
            seenAt = nil
        end
        task.wait(0.1)
    end
end)

RS.LeaderboardWatch = true
task.spawn(function()
    while RS.LeaderboardWatch do
        RF.hideLeaderboard()
        task.wait(1)
    end
end)
RS.LeaderboardRespawnConnection = LocalPlayer.CharacterAdded:Connect(function()
    for _ = 1, 6 do -- respawn: hide immediately and keep hiding while the game settles
        RF.hideLeaderboard()
        task.wait(0.5)
    end
end)

RF.ownSource()
if not RF.ownSource() then
    warn("[TSB AI] could not read own source; queue falls back to reading " .. CONFIG.ScriptFile .. " after teleport")
end
if not RF.armPersistence() then
    warn("[TSB AI] persistence OFF: death-rejoin will not reload the script")
end
if getgenv and getgenv().TSB_AI_AUTOSTART then
    getgenv().TSB_AI_AUTOSTART = nil
    task.spawn(RF.autoStart)
end
]=========]

local function log(message) pcall(warn, "[TSB AI installer] " .. message) end
local env = getgenv and getgenv() or _G
local source = BODY

if type(readfile) == "function" and type(writefile) == "function" then
    local ok, current = pcall(readfile, FILE)
    if ok and current == BODY then
        log("workspace copy up to date: running from file")
        source = current
    else
        local written, writeError = pcall(writefile, FILE, BODY)
        if written then
            log(ok and "workspace copy differed: replaced, running" or "workspace copy missing: installed, running")
        else
            log("could not write workspace copy (" .. tostring(writeError) .. "): running embedded copy")
        end
    end
else
    log("executor has no file API: running embedded copy")
end

env.TSB_AI_SOURCE = source
local fn, compileError = loadstring(source)
if not fn then
    log("compile error: " .. tostring(compileError))
    return
end
fn()
