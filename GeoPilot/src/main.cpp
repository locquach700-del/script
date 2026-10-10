// lang: C++, file: src/main.cpp, target: Geometry Dash 2.2081, Geode v5.10.1
// GeoPilot: visible scan rays, mode detection, frame ETA and pause-menu controls.
// Hazard handling is heuristic; complex triggers and arbitrary user objects need a physics solver.

#include <Geode/Geode.hpp>
#include <Geode/modify/PlayLayer.hpp>
#include <Geode/modify/PauseLayer.hpp>
#include <Geode/binding/PlayLayer.hpp>
#include <Geode/binding/PauseLayer.hpp>
#include <Geode/binding/PlayerObject.hpp>
#include <Geode/binding/GameObject.hpp>
#include <Geode/binding/GJGameLevel.hpp>
#include <Geode/binding/ButtonSprite.hpp>
#include <Geode/binding/CCMenuItemSpriteExtra.hpp>
#include <Geode/cocos/draw_nodes/CCDrawNode.h>
#include <Geode/ui/Popup.hpp>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <filesystem>
#include <functional>
#include <string>
#include <vector>

using namespace geode::prelude;

namespace {
    enum class PilotMode {
        Cube, Ship, Ball, UFO, Wave, Robot, Spider, Swing, Platformer
    };

    struct RuntimeState {
        uint64_t frame = 0;
        float dt = 0.f;
        float fps = 0.f;
        float closingRate = 0.f;
        float distance = -1.f;
        float framesToImpact = -1.f;
        float playerY = 0.f;
        int scannedObjects = 0;
        int knownHazards = 0;
        int recognizedOrbs = 0;
        int safeSurfaces = 0;
        int mapHazards = 0;
        int mapSafeSurfaces = 0;
        int mapOrbs = 0;
        int mapPortals = 0;
        int mapPads = 0;
        int mapSpeedPortals = 0;
        int mapDashRings = 0;
        float mapProgress = 0.f;
        bool mapReady = false;
        std::string routeSignal = "MAP ANALYSIS";
        std::string mode = "Unknown";
        std::string action = "INITIALIZING";
        int targetId = -1;
        int orbTargetId = -1;
        bool enabled = false;
        int experienceDeaths = 0;
        int experienceAttempts = 0;
        int experienceStreak = 0;
        std::string experienceHint = "FIRST RUN";
    };

    RuntimeState g_state;

    const char* modeName(PilotMode mode) {
        switch (mode) {
            case PilotMode::Cube: return "Cube";
            case PilotMode::Ship: return "Ship";
            case PilotMode::Ball: return "Ball";
            case PilotMode::UFO: return "UFO";
            case PilotMode::Wave: return "Wave";
            case PilotMode::Robot: return "Robot";
            case PilotMode::Spider: return "Spider";
            case PilotMode::Swing: return "Swing";
            case PilotMode::Platformer: return "Platformer";
        }
        return "Unknown";
    }

    PilotMode detectMode(PlayerObject* player) {
        if (!player) return PilotMode::Cube;
        if (player->m_isPlatformer) return PilotMode::Platformer;
        if (player->m_isDart) return PilotMode::Wave;
        if (player->m_isSwing) return PilotMode::Swing;
        if (player->m_isShip) return PilotMode::Ship;
        if (player->m_isBird) return PilotMode::UFO;
        if (player->m_isSpider) return PilotMode::Spider;
        if (player->m_isBall) return PilotMode::Ball;
        if (player->m_isRobot) return PilotMode::Robot;
        return PilotMode::Cube;
    }

    PilotMode configuredMode(std::string const& value, PlayerObject* player) {
        if (value == "Ship") return PilotMode::Ship;
        if (value == "Ball") return PilotMode::Ball;
        if (value == "UFO") return PilotMode::UFO;
        if (value == "Wave") return PilotMode::Wave;
        if (value == "Robot") return PilotMode::Robot;
        if (value == "Spider") return PilotMode::Spider;
        if (value == "Swing") return PilotMode::Swing;
        if (value == "Platformer") return PilotMode::Platformer;
        if (value == "Cube") return PilotMode::Cube;
        return detectMode(player);
    }

    // Verified sprite-to-object mappings for common lethal spikes and saw blades.
    // Decorative cogwheels and portals are intentionally not classified as hazards.
    bool isKnownHazard(int id) {
        switch (id) {
            // Standard spikes
            case 8: case 39: case 103: case 392:
            // Invisible spikes (206 is the half spike; 205 is a safe slab)
            case 144: case 145: case 206: case 459:
            // Colored and ice spikes, including tiny variants
            case 177: case 178: case 179: case 180:
            case 216: case 217: case 218: case 219: case 458:
            // Known black spikes and sloped spike hazards
            case 363: case 364: case 365:
            case 421: case 422:
            case 1716: case 1717: case 1718:
            // Common saw / blade objects
            case 740: case 741: case 742:
            case 1705: case 1706: case 1707:
            case 1708: case 1709: case 1710:
                return true;
            default:
                return false;
        }
    }

    bool isKnownSpikeID(int id) {
        switch (id) {
            case 8: case 39: case 103: case 392:
            case 144: case 145: case 206: case 459:
            case 177: case 178: case 179: case 180:
            case 216: case 217: case 218: case 219: case 458:
            case 363: case 364: case 365:
            case 421: case 422:
            case 1716: case 1717: case 1718:
                return true;
            default:
                return false;
        }
    }

    // Cube reacts only to a spike in its standing lane. A hazard entirely
    // above the player's head remains visible but never triggers a normal jump.
    bool isCubeSpikeInStandingLane(GameObject* object, CCPoint objectCenter,
                                   CCPoint playerCenter, PlayerObject* player) {
        if (!object || !player || !isKnownSpikeID(object->m_objectID)) return false;
        const float playerHalfH = std::max(6.f, player->getContentSize().height *
            std::abs(player->getScaleY()) * 0.5f);
        const float hazardHalfH = std::max(4.f, object->getContentSize().height *
            std::abs(object->getScaleY()) * 0.5f);
        const float playerHead = playerCenter.y + playerHalfH;
        const float playerFoot = playerCenter.y - playerHalfH;
        const float hazardBottom = objectCenter.y - hazardHalfH;
        const float hazardTop = objectCenter.y + hazardHalfH;
        const bool overhead = hazardBottom > playerHead + 5.f;
        const bool farBelow = hazardTop < playerFoot - 22.f;
        return !overhead && !farBelow;
    }

    // Classify by Geometry Dash's object type as well as well-known IDs.
    // This catches hazard variants whose sprite IDs are not in the legacy list.
    bool isHazardObject(GameObject* object) {
        if (!object) return false;
        return object->m_objectType == GameObjectType::Hazard ||
               object->m_objectType == GameObjectType::AnimatedHazard ||
               isKnownHazard(object->m_objectID);
    }

    // Cyan hitboxes normally correspond to solid platform geometry. These are
    // not lethal hazards; the controller may jump onto their top surface.
    bool isSafeSurface(GameObject* object) {
        if (!object) return false;
        return object->m_objectType == GameObjectType::Solid ||
               object->m_objectType == GameObjectType::Slope ||
               object->m_objectType == GameObjectType::Breakable;
    }

    bool isInteractiveOrb(GameObject* object) {
        if (!object) return false;
        switch (object->m_objectID) {
            case 36: case 84: case 141: case 1022:
            case 1330: case 1333: case 1594: case 3004: case 3027:
                return true;
            default: break;
        }
        switch (object->m_objectType) {
            case GameObjectType::YellowJumpRing:
            case GameObjectType::PinkJumpRing:
            case GameObjectType::GravityRing:
            case GameObjectType::GreenRing:
            case GameObjectType::RedJumpRing:
            case GameObjectType::CustomRing:
            case GameObjectType::DropRing:
            case GameObjectType::SpiderOrb:
            case GameObjectType::TeleportOrb:
                return true;
            default: return false;
        }
    }

    // Dash rings activate by contact rather than a jump-button tap.
    bool isContactActivatedRing(GameObject* object) {
        if (!object) return false;
        return object->m_objectType == GameObjectType::DashRing ||
               object->m_objectType == GameObjectType::GravityDashRing ||
               object->m_objectID == 1704 || object->m_objectID == 1751;
    }

    // Speed portals are Modifier objects rather than one of the form-portal
    // enum values. These are the standard GD object IDs for the speed set.
    bool isSpeedPortalObject(GameObject* object) {
        if (!object) return false;
        switch (object->m_objectID) {
            case 201: case 202: case 203: case 204: case 1334:
                return true;
            default: return false;
        }
    }

    std::string speedPortalName(GameObject* object) {
        if (!object) return "SPEED CHANGE";
        switch (object->m_objectID) {
            case 201: return "SPEED SLOW";
            case 202: return "SPEED NORMAL";
            case 203: return "SPEED FAST";
            case 204: return "SPEED FASTER";
            case 1334: return "SPEED FASTEST";
            default: return "SPEED CHANGE";
        }
    }

    bool isPortalObject(GameObject* object) {
        if (!object) return false;
        switch (object->m_objectType) {
            case GameObjectType::InverseGravityPortal:
            case GameObjectType::NormalGravityPortal:
            case GameObjectType::ShipPortal:
            case GameObjectType::CubePortal:
            case GameObjectType::InverseMirrorPortal:
            case GameObjectType::NormalMirrorPortal:
            case GameObjectType::BallPortal:
            case GameObjectType::RegularSizePortal:
            case GameObjectType::MiniSizePortal:
            case GameObjectType::UfoPortal:
            case GameObjectType::DualPortal:
            case GameObjectType::SoloPortal:
            case GameObjectType::WavePortal:
            case GameObjectType::RobotPortal:
            case GameObjectType::TeleportPortal:
            case GameObjectType::SpiderPortal:
            case GameObjectType::SwingPortal:
            case GameObjectType::GravityTogglePortal:
                return true;
            default: return false;
        }
    }

    bool isPadObject(GameObject* object) {
        if (!object) return false;
        switch (object->m_objectType) {
            case GameObjectType::YellowJumpPad:
            case GameObjectType::PinkJumpPad:
            case GameObjectType::GravityPad:
            case GameObjectType::RedJumpPad:
            case GameObjectType::SpiderPad:
                return true;
            default: return false;
        }
    }

    const char* orbName(int id) {
        switch (id) {
            case 36: return "YELLOW";
            case 84: return "BLUE";
            case 141: return "PINK";
            case 1022: return "GREEN";
            case 1330: return "BLACK";
            case 1333: return "RED";
            case 1594: return "TOGGLE";
            case 3004: return "SPIDER";
            case 3027: return "TELEPORT";
            default: return "ORB";
        }
    }

    bool holdControlMode(PilotMode mode) {
        return mode == PilotMode::Ship || mode == PilotMode::Wave;
    }

    bool pulseControlMode(PilotMode mode) {
        return mode == PilotMode::Cube || mode == PilotMode::Ball ||
               mode == PilotMode::UFO || mode == PilotMode::Robot ||
               mode == PilotMode::Spider || mode == PilotMode::Swing ||
               mode == PilotMode::Platformer;
    }

    struct ScanTarget {
        GameObject* object = nullptr;
        CCPoint point = CCPointZero;
        float dx = 0.f;
        float dy = 0.f;
        float contactDistance = 0.f;
        bool hazard = false;
        bool safeSurface = false;
        bool orb = false;
        bool contactRing = false;
    };

    enum class RouteKind { Hazard, SafeSurface, Orb, Portal, SpeedPortal, DashRing, Pad };

    struct RouteEvent {
        GameObject* object = nullptr;
        RouteKind kind = RouteKind::Hazard;
        float x = 0.f;
        int objectId = -1;
    };

    std::string orbName(GameObject* object) {
        if (!object) return "ORB";
        const int id = object->m_objectID;
        if (id == 36) return "YELLOW";
        if (id == 84) return "BLUE";
        if (id == 141) return "PINK";
        if (id == 1022) return "GREEN";
        if (id == 1330) return "BLACK";
        if (id == 1333) return "RED";
        if (id == 1594) return "TOGGLE";
        if (id == 3004) return "SPIDER";
        if (id == 3027) return "TELEPORT";
        if (id == 1704 || id == 1751) return "DASH";
        switch (object->m_objectType) {
            case GameObjectType::YellowJumpRing: return "YELLOW";
            case GameObjectType::PinkJumpRing: return "PINK";
            case GameObjectType::GravityRing: return "BLUE";
            case GameObjectType::GreenRing: return "GREEN";
            case GameObjectType::RedJumpRing: return "RED";
            case GameObjectType::SpiderOrb: return "SPIDER";
            case GameObjectType::TeleportOrb: return "TELEPORT";
            case GameObjectType::CustomRing: return "CUSTOM";
            case GameObjectType::DropRing: return "BLACK/DROP";
            case GameObjectType::DashRing: return "DASH";
            case GameObjectType::GravityDashRing: return "GRAVITY DASH";
            default: return "ORB";
        }
    }

    std::string routeKindName(RouteKind kind, GameObject* object) {
        switch (kind) {
            case RouteKind::Hazard: return "DODGE RED";
            case RouteKind::SafeSurface: return "LAND BLUE";
            case RouteKind::Orb: return fmt::format("TAP {}", orbName(object));
            case RouteKind::Portal: return "MODE PORTAL";
            case RouteKind::SpeedPortal: return speedPortalName(object);
            case RouteKind::DashRing: return "DASH / CONTACT";
            case RouteKind::Pad: return "AUTO PAD";
        }
        return "CHECK";
    }

    CCPoint nodeCenterInParent(CCNode* node, CCNode* parent) {
        if (!node || !parent) return CCPointZero;
        auto size = node->getContentSize();
        auto world = node->convertToWorldSpace({size.width * 0.5f, size.height * 0.5f});
        return parent->convertToNodeSpace(world);
    }

    float approximateHalfWidth(GameObject* object) {
        if (!object) return 0.f;
        return std::max(2.f, object->getContentSize().width * std::abs(object->getScaleX()) * 0.5f);
    }

    std::string etaText(float frames) {
        if (frames < 0.f || frames > 9999.f) return "--";
        return fmt::format("{:.0f}f", std::max(0.f, frames));
    }

    std::string learningKeyForLevel(GJGameLevel* level) {
        if (!level) return "learning/level-unknown";
        if (level->m_levelID != 0)
            return fmt::format("learning/level-{}", level->m_levelID);
        return fmt::format("learning/local-{}", std::hash<std::string>{}(level->m_levelName));
    }

    CCSprite* createGeoPilotLogo() {
        const auto base = Mod::get()->getResourcesDir();
        const std::filesystem::path candidates[] = {
            base / "geopilot-logo.png",
            base / "resources" / "geopilot-logo.png"
        };
        for (auto const& path : candidates) {
            if (!std::filesystem::exists(path)) continue;
            if (auto sprite = CCSprite::create(path.string().c_str())) return sprite;
        }
        log::warn("GeoPilot logo could not be loaded from mod resources: {}", base.string());
        return nullptr;
    }
}

class $modify(GeoPilotPlayLayer, PlayLayer) {
    struct Fields {
        cocos2d::CCDrawNode* scanDraw = nullptr;
        CCLabelBMFont* hudLabel = nullptr;
        uint64_t frameCount = 0;
        float elapsed = 0.f;
        float previousDt = 0.f;
        float previousNearestDx = -1.f;
        GameObject* previousNearest = nullptr;
        GameObject* lastTriggeredHazard = nullptr;
        GameObject* lastOrbApproach = nullptr;
        GameObject* lastOrbTriggered = nullptr;
        GameObject* lastSafePlatform = nullptr;
        std::vector<RouteEvent> routePlan;
        float mapStartX = 0.f;
        float mapEndX = 0.f;
        int mapHazards = 0;
        int mapSafeSurfaces = 0;
        int mapOrbs = 0;
        int mapPortals = 0;
        int mapPads = 0;
        int mapSpeedPortals = 0;
        int mapDashRings = 0;
        bool mapAnalyzed = false;
        float lastTriggeredX = -100000.f;
        int lastTriggeredId = -1;
        float releaseCooldown = 0.f;
        bool releaseNextFrame = false;
        bool jumpHeld = false;
        bool rightHeld = false;
        float logTimer = 0.f;
        bool deathRecordedThisRun = false;
        std::string learningKey;
        int experienceDeaths = 0;
        int experienceAttempts = 0;
        int repeatFailures = 0;
        int learnedHazardId = -1;
        float learnedHazardDistance = -1.f;
        std::string learnedLastAction = "NONE";
    };

    bool init(GJGameLevel* level, bool useReplay, bool dontCreateObjects) {
        if (!PlayLayer::init(level, useReplay, dontCreateObjects)) return false;

        m_fields->scanDraw = cocos2d::CCDrawNode::create();
        this->addChild(m_fields->scanDraw, 99990);

        m_fields->hudLabel = CCLabelBMFont::create("", "chatFont.fnt");
        if (m_fields->hudLabel) {
            m_fields->hudLabel->setAnchorPoint({0.f, 1.f});
            m_fields->hudLabel->setPosition({10.f, CCDirector::sharedDirector()->getWinSize().height - 10.f});
            m_fields->hudLabel->setScale(0.55f);
            m_fields->hudLabel->setColor({150, 235, 255});
            this->addChild(m_fields->hudLabel, 99991);
        }

        m_fields->frameCount = 0;
        m_fields->elapsed = 0.f;
        m_fields->previousNearest = nullptr;
        m_fields->lastTriggeredHazard = nullptr;
        m_fields->lastOrbApproach = nullptr;
        m_fields->lastOrbTriggered = nullptr;
        m_fields->lastSafePlatform = nullptr;
        m_fields->deathRecordedThisRun = false;
        m_fields->learningKey = learningKeyForLevel(level);
        auto* memory = Mod::get();
        m_fields->experienceDeaths = memory->getSavedValue<int>(m_fields->learningKey + "/deaths", 0);
        m_fields->experienceAttempts = memory->getSavedValue<int>(m_fields->learningKey + "/attempts", 0) + 1;
        m_fields->repeatFailures = memory->getSavedValue<int>(m_fields->learningKey + "/repeat-failures", 0);
        m_fields->learnedHazardId = memory->getSavedValue<int>(m_fields->learningKey + "/last-hazard-id", -1);
        m_fields->learnedHazardDistance = memory->getSavedValue<float>(m_fields->learningKey + "/last-hazard-distance", -1.f);
        m_fields->learnedLastAction = memory->getSavedValue<std::string>(m_fields->learningKey + "/last-action", "NONE");
        memory->setSavedValue<int>(m_fields->learningKey + "/attempts", m_fields->experienceAttempts);
        g_state.experienceDeaths = m_fields->experienceDeaths;
        g_state.experienceAttempts = m_fields->experienceAttempts;
        g_state.experienceStreak = m_fields->repeatFailures;
        g_state.experienceHint = m_fields->learnedLastAction == "NONE"
            ? "FIRST RUN" : fmt::format("RETRY {}", m_fields->learnedLastAction);

        // Preflight the entire already-loaded level object list before Auto Play
        // can make its first decision. This is a static route inventory, not a
        // full physics simulation; live timing is still recalculated every frame.
        m_fields->routePlan.clear();
        m_fields->mapHazards = 0;
        m_fields->mapSafeSurfaces = 0;
        m_fields->mapOrbs = 0;
        m_fields->mapPortals = 0;
        m_fields->mapPads = 0;
        m_fields->mapSpeedPortals = 0;
        m_fields->mapDashRings = 0;
        const CCPoint initialPlayer = m_player1 ? nodeCenterInParent(m_player1, this) : CCPointZero;
        m_fields->mapStartX = initialPlayer.x;
        m_fields->mapEndX = initialPlayer.x;

        auto initialObjects = geode::cocos::CCArrayExt<GameObject*>(m_objects);
        for (auto* object : initialObjects) {
            if (!object || object == m_player1 || object->m_objectID < 0) continue;
            const auto p = nodeCenterInParent(object, this);
            m_fields->mapEndX = std::max(m_fields->mapEndX, p.x);

            RouteKind kind;
            bool relevant = true;
            if (isHazardObject(object)) {
                kind = RouteKind::Hazard;
                ++m_fields->mapHazards;
            } else if (isContactActivatedRing(object)) {
                kind = RouteKind::DashRing;
                ++m_fields->mapDashRings;
            } else if (isInteractiveOrb(object)) {
                kind = RouteKind::Orb;
                ++m_fields->mapOrbs;
            } else if (isSpeedPortalObject(object)) {
                kind = RouteKind::SpeedPortal;
                ++m_fields->mapSpeedPortals;
            } else if (isPortalObject(object)) {
                kind = RouteKind::Portal;
                ++m_fields->mapPortals;
            } else if (isPadObject(object)) {
                kind = RouteKind::Pad;
                ++m_fields->mapPads;
            } else if (isSafeSurface(object)) {
                kind = RouteKind::SafeSurface;
                ++m_fields->mapSafeSurfaces;
            } else {
                relevant = false;
            }

            if (relevant) {
                m_fields->routePlan.push_back({object, kind, p.x, object->m_objectID});
            }
        }

        std::sort(m_fields->routePlan.begin(), m_fields->routePlan.end(),
            [](RouteEvent const& a, RouteEvent const& b) { return a.x < b.x; });
        m_fields->mapAnalyzed = true;
        g_state.mapReady = true;
        g_state.mapHazards = m_fields->mapHazards;
        g_state.mapSafeSurfaces = m_fields->mapSafeSurfaces;
        g_state.mapOrbs = m_fields->mapOrbs;
        g_state.mapPortals = m_fields->mapPortals;
        g_state.mapPads = m_fields->mapPads;
        g_state.mapSpeedPortals = m_fields->mapSpeedPortals;
        g_state.mapDashRings = m_fields->mapDashRings;
        g_state.routeSignal = fmt::format(
            "MAP READY H{} B{} O{} P{} SPD{} DASH{} PAD{}",
            m_fields->mapHazards, m_fields->mapSafeSurfaces, m_fields->mapOrbs,
            m_fields->mapPortals, m_fields->mapSpeedPortals, m_fields->mapDashRings, m_fields->mapPads);
        log::info("GeoPilot preflight: events={} hazards={} safe-surfaces={} orbs={} portals={} speed-portals={} dash-rings={} pads={}",
            m_fields->routePlan.size(), m_fields->mapHazards, m_fields->mapSafeSurfaces,
            m_fields->mapOrbs, m_fields->mapPortals, m_fields->mapSpeedPortals, m_fields->mapDashRings, m_fields->mapPads);
        return true;
    }

    void postUpdate(float dt) {
        PlayLayer::postUpdate(dt);

        auto mod = Mod::get();
        auto* player = m_player1;
        const bool enabled = mod->getSettingValue<bool>("auto-play");
        const bool raysEnabled = mod->getSettingValue<bool>("show-rays");
        const bool hudEnabled = mod->getSettingValue<bool>("show-hud");

        if (m_fields->releaseNextFrame && player) {
            player->releaseButton(PlayerButton::Jump);
            m_fields->releaseNextFrame = false;
            m_fields->jumpHeld = false;
        }

        if (player && !player->m_isDead) m_fields->deathRecordedThisRun = false;
        if (!player || player->m_isDead || m_isPaused) {
            if (m_fields->scanDraw) m_fields->scanDraw->clear();
            if (m_fields->hudLabel) m_fields->hudLabel->setVisible(false);
            if (player && player->m_isDead) {
                if (!m_fields->deathRecordedThisRun) {
                    auto* memory = Mod::get();
                    m_fields->experienceDeaths = memory->getSavedValue<int>(m_fields->learningKey + "/deaths", 0) + 1;
                    memory->setSavedValue<int>(m_fields->learningKey + "/deaths", m_fields->experienceDeaths);
                    const int previousHazardId = memory->getSavedValue<int>(m_fields->learningKey + "/last-hazard-id", -1);
                    const float previousDistance = memory->getSavedValue<float>(m_fields->learningKey + "/last-hazard-distance", -1.f);
                    const int previousStreak = memory->getSavedValue<int>(m_fields->learningKey + "/repeat-failures", 0);
                    const bool sameFailure = g_state.targetId >= 0 &&
                        previousHazardId == g_state.targetId && previousDistance >= 0.f &&
                        std::abs(g_state.distance - previousDistance) <= 52.f;
                    m_fields->repeatFailures = sameFailure ? previousStreak + 1 :
                        (g_state.targetId >= 0 ? 1 : 0);
                    memory->setSavedValue<int>(m_fields->learningKey + "/repeat-failures", m_fields->repeatFailures);
                    memory->setSavedValue<int>(m_fields->learningKey + "/last-hazard-id", g_state.targetId);
                    memory->setSavedValue<float>(m_fields->learningKey + "/last-hazard-distance", g_state.distance);
                    memory->setSavedValue<std::string>(m_fields->learningKey + "/last-action", g_state.action);
                    m_fields->learnedHazardId = g_state.targetId;
                    m_fields->learnedHazardDistance = g_state.distance;
                    m_fields->learnedLastAction = g_state.action;
                    g_state.experienceDeaths = m_fields->experienceDeaths;
                    g_state.experienceAttempts = m_fields->experienceAttempts;
                    g_state.experienceStreak = m_fields->repeatFailures;
                    g_state.experienceHint = fmt::format("DIED: {}", g_state.action);
                    if (m_fields->repeatFailures >= 3) {
                        memory->setSettingValue<bool>("auto-play", false);
                        g_state.enabled = false;
                        g_state.action = "SAFE STOP / SAME DEATH x3";
                        g_state.experienceHint = "AUTO OFF / REPEATED DEATH";
                    }
                    m_fields->deathRecordedThisRun = true;
                    log::info("GeoPilot learning: level deaths={} attempts={} target={} distance={:.1f} action={}",
                        m_fields->experienceDeaths, m_fields->experienceAttempts, g_state.targetId,
                        g_state.distance, g_state.action);
                }
                m_fields->previousNearest = nullptr;
                m_fields->lastTriggeredHazard = nullptr;
                m_fields->lastOrbApproach = nullptr;
                m_fields->lastOrbTriggered = nullptr;
                m_fields->lastSafePlatform = nullptr;
                m_fields->jumpHeld = false;
            }
            return;
        }

        ++m_fields->frameCount;
        m_fields->elapsed += std::max(0.f, dt);
        m_fields->releaseCooldown = std::max(0.f, m_fields->releaseCooldown - dt);
        m_fields->logTimer = std::max(0.f, m_fields->logTimer - dt);

        const auto modeSetting = mod->getSettingValue<std::string>("control-mode");
        const PilotMode mode = configuredMode(modeSetting, player);
        const float scanDistance = static_cast<float>(mod->getSettingValue<int64_t>("reaction-distance"));
        const int leadFrames = static_cast<int>(mod->getSettingValue<int64_t>("lead-frames"));

        const CCPoint playerCenter = nodeCenterInParent(player, this);
        g_state.frame = m_fields->frameCount;
        g_state.dt = dt;
        g_state.fps = dt > 0.00001f ? 1.f / dt : 0.f;
        g_state.mode = modeName(mode);
        g_state.enabled = enabled;
        g_state.playerY = playerCenter.y;
        g_state.scannedObjects = 0;
        g_state.knownHazards = 0;
        g_state.recognizedOrbs = 0;
        g_state.safeSurfaces = 0;
        g_state.mapReady = m_fields->mapAnalyzed;
        g_state.mapHazards = m_fields->mapHazards;
        g_state.mapSafeSurfaces = m_fields->mapSafeSurfaces;
        g_state.mapOrbs = m_fields->mapOrbs;
        g_state.mapPortals = m_fields->mapPortals;
        g_state.mapPads = m_fields->mapPads;
        g_state.mapProgress = (m_fields->mapEndX > m_fields->mapStartX)
            ? std::clamp((playerCenter.x - m_fields->mapStartX) /
                         (m_fields->mapEndX - m_fields->mapStartX), 0.f, 1.f) * 100.f
            : 0.f;
        g_state.distance = -1.f;
        g_state.framesToImpact = -1.f;
        g_state.targetId = -1;
        g_state.orbTargetId = -1;
        g_state.closingRate = 0.f;
        g_state.action = enabled ? "SCANNING" : "SCAN ONLY";

        std::vector<ScanTarget> targets;
        std::vector<ScanTarget> hazards;
        std::vector<ScanTarget> safeSurfaces;
        std::vector<ScanTarget> orbs;
        auto objects = geode::cocos::CCArrayExt<GameObject*>(m_objects);

        for (auto* object : objects) {
            if (!object || object == player || object->m_objectID < 0) continue;
            const CCPoint objectCenter = nodeCenterInParent(object, this);
            const float dx = objectCenter.x - playerCenter.x;
            const float dy = objectCenter.y - playerCenter.y;

            // Scan only the forward sector and nearby vertical band.
            if (dx < -35.f || dx > scanDistance || std::abs(dy) > 300.f) continue;

            ++g_state.scannedObjects;
            const bool hazard = isHazardObject(object);
            const bool safeSurface = isSafeSurface(object);
            const bool orb = isInteractiveOrb(object);
            const bool contactRing = isContactActivatedRing(object);
            if (hazard) ++g_state.knownHazards;
            if (safeSurface) ++g_state.safeSurfaces;
            if (orb) ++g_state.recognizedOrbs;

            ScanTarget target;
            target.object = object;
            target.point = objectCenter;
            target.dx = dx;
            target.dy = dy;
            target.hazard = hazard;
            target.safeSurface = safeSurface;
            target.orb = orb;
            target.contactRing = contactRing;
            target.contactDistance = dx - approximateHalfWidth(object) - approximateHalfWidth(player);
            targets.push_back(target);
            const bool actionableHazard = mode == PilotMode::Cube
                ? isCubeSpikeInStandingLane(object, objectCenter, playerCenter, player)
                : hazard;
            if (actionableHazard && dx > 0.f) hazards.push_back(target);
            if (safeSurface && dx > 0.f) safeSurfaces.push_back(target);
            if ((orb || contactRing) && dx > -8.f && std::abs(dy) <= 220.f) orbs.push_back(target);
        }

        std::sort(targets.begin(), targets.end(), [](ScanTarget const& a, ScanTarget const& b) {
            return a.dx < b.dx;
        });
        std::sort(hazards.begin(), hazards.end(), [](ScanTarget const& a, ScanTarget const& b) {
            return a.contactDistance < b.contactDistance;
        });
        std::sort(orbs.begin(), orbs.end(), [](ScanTarget const& a, ScanTarget const& b) {
            return a.dx < b.dx;
        });
        std::sort(safeSurfaces.begin(), safeSurfaces.end(), [](ScanTarget const& a, ScanTarget const& b) {
            return a.contactDistance < b.contactDistance;
        });

        ScanTarget const* nearestHazard = hazards.empty() ? nullptr : &hazards.front();
        ScanTarget const* nearestOrb = orbs.empty() ? nullptr : &orbs.front();
        ScanTarget const* nearestSafeSurface = safeSurfaces.empty() ? nullptr : &safeSurfaces.front();
        if (nearestOrb) g_state.orbTargetId = nearestOrb->object->m_objectID;

        // Produce a route signal from the preflight map: the next few events are
        // ordered by position and described as dodge / land / orb / portal / pad.
        std::string routeSignal;
        int planItems = 0;
        float lastSafeSignalX = -100000.f;
        for (auto const& event : m_fields->routePlan) {
            if (!event.object || event.object->m_isDisabled) continue;
            const CCPoint eventPoint = nodeCenterInParent(event.object, this);
            const float dx = eventPoint.x - playerCenter.x;
            if (dx < -22.f) continue;
            if (mode == PilotMode::Cube && event.kind == RouteKind::Hazard &&
                !isCubeSpikeInStandingLane(event.object, eventPoint, playerCenter, player)) continue;
            if (event.kind == RouteKind::SafeSurface && dx - lastSafeSignalX < 42.f) continue;
            if (event.kind == RouteKind::SafeSurface) lastSafeSignalX = dx;
            if (planItems > 0) routeSignal += "  >  ";
            routeSignal += fmt::format("{} +{:.0f}", routeKindName(event.kind, event.object), std::max(0.f, dx));
            if (++planItems >= 3) break;
        }
        g_state.routeSignal = planItems ? routeSignal : "ROUTE END / MAP PRECHECK DONE";

        float closingPerFrame = 0.f;
        if (nearestHazard && nearestHazard->object == m_fields->previousNearest &&
            m_fields->previousNearestDx >= 0.f) {
            const float observedClosing = m_fields->previousNearestDx - nearestHazard->dx;
            if (observedClosing > 0.05f && observedClosing < 80.f)
                closingPerFrame = observedClosing;
        }

        if (closingPerFrame <= 0.05f) {
            const float estimatedSpeed = static_cast<float>(std::abs(player->getCurrentXVelocity()) * std::max(dt, 1.f / 240.f));
            closingPerFrame = std::clamp(estimatedSpeed, 0.6f, 40.f);
        }
        g_state.closingRate = closingPerFrame;

        float framesToImpact = -1.f;
        float contactDistance = -1.f;
        if (nearestHazard) {
            contactDistance = nearestHazard->contactDistance;
            framesToImpact = std::max(0.f, contactDistance) / std::max(0.1f, closingPerFrame);
            g_state.distance = nearestHazard->dx;
            g_state.framesToImpact = framesToImpact;
            g_state.targetId = nearestHazard->object->m_objectID;
        }
        m_fields->previousNearest = nearestHazard ? nearestHazard->object : nullptr;
        m_fields->previousNearestDx = nearestHazard ? nearestHazard->dx : -1.f;

        // Visual scan: forward fan plus target rays and boxes. Coordinates are converted
        // through world space so the overlay follows the camera/scroll transform.
        if (m_fields->scanDraw) {
            auto draw = m_fields->scanDraw;
            draw->clear();
            draw->setVisible(raysEnabled);
            if (raysEnabled) {
                const auto cyan = cocos2d::ccColor4F{0.20f, 0.82f, 1.00f, 0.52f};
                const auto blue = cocos2d::ccColor4F{0.25f, 0.50f, 1.00f, 0.68f};
                const auto red = cocos2d::ccColor4F{1.00f, 0.18f, 0.22f, 0.95f};
                const auto amber = cocos2d::ccColor4F{1.00f, 0.65f, 0.15f, 0.85f};

                const float rayLength = std::min(scanDistance, 650.f);
                draw->drawSegment(playerCenter, {playerCenter.x + rayLength, playerCenter.y}, 1.4f, cyan);
                draw->drawSegment(playerCenter, {playerCenter.x + rayLength, playerCenter.y + rayLength * 0.25f}, 0.8f, cyan);
                draw->drawSegment(playerCenter, {playerCenter.x + rayLength, playerCenter.y - rayLength * 0.25f}, 0.8f, cyan);
                draw->drawSegment(playerCenter, {playerCenter.x + rayLength, playerCenter.y + rayLength * 0.12f}, 0.7f, cyan);
                draw->drawSegment(playerCenter, {playerCenter.x + rayLength, playerCenter.y - rayLength * 0.12f}, 0.7f, cyan);

                int rayCount = 0;
                for (auto const& target : targets) {
                    if (rayCount >= 8) break;
                    if (target.dx < 0.f) continue;
                    const auto green = cocos2d::ccColor4F{0.12f, 1.00f, 0.52f, 0.92f};
                    const auto safeCyan = cocos2d::ccColor4F{0.20f, 0.82f, 1.00f, 0.92f};
                    const auto lineColor = target.hazard ? red :
                        ((target.orb || target.contactRing) ? green : (target.safeSurface ? safeCyan : blue));
                    draw->drawSegment(playerCenter, target.point,
                        (target.hazard || target.orb || target.safeSurface) ? 1.6f : 0.7f, lineColor);
                    if (target.orb || target.contactRing) {
                        const float radius = 12.f;
                        const CCPoint top{target.point.x, target.point.y + radius};
                        const CCPoint right{target.point.x + radius, target.point.y};
                        const CCPoint bottom{target.point.x, target.point.y - radius};
                        const CCPoint left{target.point.x - radius, target.point.y};
                        draw->drawSegment(top, right, 1.7f, green);
                        draw->drawSegment(right, bottom, 1.7f, green);
                        draw->drawSegment(bottom, left, 1.7f, green);
                        draw->drawSegment(left, top, 1.7f, green);
                    }
                    if (target.hazard || target.safeSurface) {
                        const float halfW = std::clamp(approximateHalfWidth(target.object), 6.f, 26.f);
                        const auto size = target.object->getContentSize();
                        const float halfH = std::clamp(size.height * std::abs(target.object->getScaleY()) * 0.5f, 6.f, 26.f);
                        CCPoint tl{target.point.x - halfW, target.point.y + halfH};
                        CCPoint tr{target.point.x + halfW, target.point.y + halfH};
                        CCPoint bl{target.point.x - halfW, target.point.y - halfH};
                        CCPoint br{target.point.x + halfW, target.point.y - halfH};
                        const auto boxColor = target.hazard ? amber : safeCyan;
                        const auto dotColor = target.hazard ? red : safeCyan;
                        draw->drawDot(target.point, 4.f, dotColor);
                        draw->drawSegment(tl, tr, 1.2f, boxColor);
                        draw->drawSegment(tr, br, 1.0f, boxColor);
                        draw->drawSegment(br, bl, 1.0f, boxColor);
                        draw->drawSegment(bl, tl, 1.0f, boxColor);
                        if (target.safeSurface) {
                            draw->drawSegment(tl, tr, 2.0f, safeCyan); // cyan top/landing marker
                        }
                    }
                    ++rayCount;
                }

                if (nearestHazard) {
                    draw->drawSegment(playerCenter, nearestHazard->point, 2.4f, red);
                    draw->drawDot(playerCenter, 4.f, cyan);
                }
                if (nearestOrb) {
                    draw->drawSegment(playerCenter, nearestOrb->point, 1.8f, cocos2d::ccColor4F{0.12f, 1.00f, 0.52f, 0.92f});
                }
                if (nearestSafeSurface) {
                    draw->drawSegment(playerCenter, nearestSafeSurface->point, 1.4f,
                        cocos2d::ccColor4F{0.20f, 0.82f, 1.00f, 0.75f});
                }
            }
        }

        // Fast controller with separate target logic:
        // red = lethal dodge, cyan = safe solid surface, green = jump-activated orb.
        const bool orbAssist = mod->getSettingValue<bool>("orb-assist");
        bool orbAction = false;
        bool platformAction = false;
        const float playerHalfW = approximateHalfWidth(player);
        const float playerHalfH = std::max(6.f, player->getContentSize().height *
            std::abs(player->getScaleY()) * 0.5f);

        if (enabled && orbAssist && nearestOrb && m_fields->releaseCooldown <= 0.f) {
            const float orbHalfW = approximateHalfWidth(nearestOrb->object);
            const float orbHalfH = std::max(6.f, nearestOrb->object->getContentSize().height *
                std::abs(nearestOrb->object->getScaleY()) * 0.5f);
            const float edgeGapX = nearestOrb->dx - playerHalfW - orbHalfW;
            const float edgeGapY = std::abs(nearestOrb->dy) - playerHalfH - orbHalfH;
            const float orbLead = std::clamp(closingPerFrame * 1.15f + 1.f, 3.f, 13.f);
            const bool inOrbContactWindow =
                edgeGapX <= orbLead && edgeGapX >= -10.f &&
                edgeGapY <= 10.f && nearestOrb->dx >= -16.f;

            const float orbApproachDistance = std::clamp(
                closingPerFrame * 4.5f + std::max(0.f, nearestOrb->dy) * 0.20f,
                44.f, 100.f);
            const bool shouldApproachOrb = pulseControlMode(mode) &&
                nearestOrb->dy > std::max(28.f, playerHalfH + orbHalfH * 0.45f) &&
                nearestOrb->contactDistance <= orbApproachDistance &&
                nearestOrb->contactDistance > orbLead + 10.f &&
                nearestOrb->dx > 10.f &&
                nearestOrb->object != m_fields->lastOrbApproach;

            if (isContactActivatedRing(nearestOrb->object)) {
                if (inOrbContactWindow) {
                    // Dash rings are contact-activated. Never pulse Jump just to activate one.
                    g_state.action = "DASH RING / CONTACT";
                    orbAction = true;
                } else {
                    g_state.action = "TRACK DASH / CONTACT";
                }
            } else if (inOrbContactWindow && nearestOrb->object != m_fields->lastOrbTriggered) {
                player->pushButton(PlayerButton::Jump);
                m_fields->releaseNextFrame = true;
                m_fields->releaseCooldown = 0.095f;
                m_fields->lastOrbTriggered = nearestOrb->object;
                g_state.action = fmt::format("ORB TAP / {}", orbName(nearestOrb->object));
                orbAction = true;
            } else if (shouldApproachOrb) {
                player->pushButton(PlayerButton::Jump);
                m_fields->releaseNextFrame = true;
                m_fields->releaseCooldown = 0.15f;
                m_fields->lastOrbApproach = nearestOrb->object;
                g_state.action = fmt::format("APPROACH / {}", orbName(nearestOrb->object));
                orbAction = true;
            }
        }

        // Safe blocks are not red danger. If the next cyan solid is a genuine step-up,
        // jump only inside a short lead window and prefer its top unless a hazard covers it.
        bool safeStepNeedsJump = false;
        bool landingTopBlocked = false;
        float platformTriggerDistance = 0.f;
        float selectedStepHeight = 0.f;
        ScanTarget const* stepSurfaceTarget = nullptr;

        // Skip same-height floor blocks; select the first cyan platform whose top
        // actually requires a jump from the player's current feet height.
        for (auto const& platform : safeSurfaces) {
            const float platformHalfH = std::max(4.f,
                platform.object->getContentSize().height *
                std::abs(platform.object->getScaleY()) * 0.5f);
            const float playerFoot = playerCenter.y - playerHalfH;
            const float platformTop = platform.point.y + platformHalfH;
            const float stepHeight = platformTop - playerFoot;
            if (stepHeight > 8.f && stepHeight < 118.f &&
                platform.contactDistance > -10.f &&
                platform.contactDistance < 180.f) {
                stepSurfaceTarget = &platform;
                selectedStepHeight = stepHeight;
                break;
            }
        }

        if (stepSurfaceTarget && pulseControlMode(mode) && mode != PilotMode::Cube) {
            platformTriggerDistance = std::clamp(
                closingPerFrame * static_cast<float>(leadFrames) +
                std::max(0.f, selectedStepHeight) * 0.22f + 4.f, 22.f, 82.f);

            const float platformHalfH = std::max(4.f,
                stepSurfaceTarget->object->getContentSize().height *
                std::abs(stepSurfaceTarget->object->getScaleY()) * 0.5f);
            const float platformTopY = stepSurfaceTarget->point.y + platformHalfH;
            const float platformRight = stepSurfaceTarget->point.x +
                approximateHalfWidth(stepSurfaceTarget->object);

            for (auto const& danger : hazards) {
                const float hazardHalfW = approximateHalfWidth(danger.object);
                const float hazardHalfH = std::max(4.f,
                    danger.object->getContentSize().height *
                    std::abs(danger.object->getScaleY()) * 0.5f);
                const bool overlapsPlatformRun =
                    danger.point.x + hazardHalfW > stepSurfaceTarget->point.x - playerHalfW &&
                    danger.point.x - hazardHalfW < platformRight + playerHalfW;
                const bool hazardAboveTop =
                    danger.point.y - hazardHalfH < platformTopY + 88.f &&
                    danger.point.y + hazardHalfH > platformTopY + 2.f;
                if (overlapsPlatformRun && hazardAboveTop) {
                    landingTopBlocked = true;
                    break;
                }
            }
            safeStepNeedsJump = true;
        }

        if (enabled && mode == PilotMode::Platformer && !m_fields->rightHeld) {
            player->pushButton(PlayerButton::Right);
            m_fields->rightHeld = true;
        }

        if (orbAction) {
            // Keep the orb input for this frame; don't override it with another mode.
        } else if (!enabled) {
            if (m_fields->jumpHeld) {
                player->releaseButton(PlayerButton::Jump);
                m_fields->jumpHeld = false;
            }
            if (m_fields->rightHeld) {
                player->releaseButton(PlayerButton::Right);
                m_fields->rightHeld = false;
            }
        } else if (holdControlMode(mode)) {
            bool wantHold = false;
            const float steeringWindow = std::max(7.f, static_cast<float>(leadFrames * 1.6f));
            const bool imminentHazard = nearestHazard && framesToImpact >= 0.f &&
                                         framesToImpact <= steeringWindow;
            if (imminentHazard) {
                wantHold = nearestHazard->dy < -8.f;
                g_state.action = wantHold ? "HOLD / CLIMB" : "RELEASE / DESCEND";
            } else {
                const float midline = CCDirector::sharedDirector()->getWinSize().height * 0.52f;
                wantHold = playerCenter.y < midline - 18.f;
                g_state.action = wantHold ? "HOLD / CENTER" : "RELEASE / CENTER";
            }

            if (wantHold != m_fields->jumpHeld) {
                if (wantHold) player->pushButton(PlayerButton::Jump);
                else player->releaseButton(PlayerButton::Jump);
                m_fields->jumpHeld = wantHold;
            }
        } else if (safeStepNeedsJump && !landingTopBlocked &&
                   stepSurfaceTarget->contactDistance <= platformTriggerDistance &&
                   stepSurfaceTarget->object != m_fields->lastSafePlatform &&
                   (!nearestHazard || stepSurfaceTarget->contactDistance <= nearestHazard->contactDistance + 8.f) &&
                   m_fields->releaseCooldown <= 0.f) {
            player->pushButton(PlayerButton::Jump);
            m_fields->releaseNextFrame = true;
            m_fields->releaseCooldown = 0.095f;
            m_fields->lastSafePlatform = stepSurfaceTarget->object;
            g_state.action = fmt::format("JUMP TO SAFE BLOCK / +{:.0f}px", platformTriggerDistance);
            platformAction = true;
        } else if (nearestHazard && pulseControlMode(mode) && m_fields->releaseCooldown <= 0.f) {
            int learnedExtraFrames = 0;
            const bool sameLearnedSpike =
                nearestHazard->object->m_objectID == m_fields->learnedHazardId &&
                m_fields->learnedHazardDistance >= 0.f &&
                std::abs(nearestHazard->dx - m_fields->learnedHazardDistance) <= 52.f;
            if (sameLearnedSpike && m_fields->experienceDeaths > 0 &&
                m_fields->learnedLastAction.find("ORB") == std::string::npos) {
                learnedExtraFrames = std::min(2, m_fields->experienceDeaths);
            }
            const float speedLeadDistance = closingPerFrame * static_cast<float>(leadFrames + learnedExtraFrames);
            const float triggerDistance = std::clamp(speedLeadDistance + 4.f, 20.f, 72.f);
            const int effectiveLeadFrames = leadFrames + learnedExtraFrames;
            const bool inTimingWindow =
                (framesToImpact >= 0.f && framesToImpact <= static_cast<float>(effectiveLeadFrames)) ||
                nearestHazard->contactDistance <= triggerDistance;

            if (!inTimingWindow) {
                g_state.action = fmt::format("DODGE RED / ETA {} / TRIG {:.0f}",
                    etaText(framesToImpact), triggerDistance);
            } else {
                const bool sameHazard = nearestHazard->object == m_fields->lastTriggeredHazard;
                if (!sameHazard) {
                    player->pushButton(PlayerButton::Jump);
                    m_fields->releaseNextFrame = true;
                    m_fields->releaseCooldown = 0.09f;
                    m_fields->lastTriggeredHazard = nearestHazard->object;
                    m_fields->lastTriggeredX = nearestHazard->point.x;
                    m_fields->lastTriggeredId = nearestHazard->object->m_objectID;
                    g_state.action = learnedExtraFrames > 0
                        ? fmt::format("LEARNED DODGE / +{}F", learnedExtraFrames)
                        : fmt::format("DODGE RED / {}F", leadFrames);
                } else {
                    g_state.action = "TRACK RED / ALREADY TAPPED";
                }
            }
        } else if (enabled) {
            if (mode == PilotMode::Platformer) {
                g_state.action = nearestHazard
                    ? fmt::format("MOVE RIGHT / DODGE ETA {}", etaText(framesToImpact))
                    : "MOVE RIGHT / ROUTE CLEAR";
            } else if (safeStepNeedsJump && landingTopBlocked) {
                g_state.action = "SAFE BLOCK / TOP BLOCKED BY RED";
            } else if (safeStepNeedsJump) {
                g_state.action = "SAFE BLOCK / ALIGN LANDING";
            } else if (nearestSafeSurface && std::abs(
                       (nearestSafeSurface->point.y +
                        nearestSafeSurface->object->getContentSize().height *
                        std::abs(nearestSafeSurface->object->getScaleY()) * 0.5f) -
                       (playerCenter.y - playerHalfH)) < 8.f) {
                g_state.action = "SAFE SURFACE / LAND";
            } else if (nearestOrb) {
                g_state.action = fmt::format("TRACK ORB / {}", orbName(nearestOrb->object));
            } else {
                g_state.action = nearestHazard ? fmt::format("TRACK RED / ETA {}", etaText(framesToImpact)) : "ROUTE CLEAR";
            }
        }

        // Forget a target after passing it so a retry or a loop does not permanently lock it out.
        if (m_fields->lastTriggeredHazard && nearestHazard == nullptr) {
            m_fields->lastTriggeredHazard = nullptr;
        } else if (m_fields->lastTriggeredHazard && nearestHazard &&
                   nearestHazard->object != m_fields->lastTriggeredHazard &&
                   nearestHazard->dx < -40.f) {
            m_fields->lastTriggeredHazard = nullptr;
        }
        if (m_fields->lastOrbTriggered && !nearestOrb) m_fields->lastOrbTriggered = nullptr;
        if (m_fields->lastOrbApproach && !nearestOrb) m_fields->lastOrbApproach = nullptr;
        if (m_fields->lastOrbTriggered && nearestOrb &&
            nearestOrb->object != m_fields->lastOrbTriggered && nearestOrb->dx < -36.f) {
            m_fields->lastOrbTriggered = nullptr;
        }
        if (m_fields->lastOrbApproach && nearestOrb &&
            nearestOrb->object != m_fields->lastOrbApproach && nearestOrb->dx < -36.f) {
            m_fields->lastOrbApproach = nullptr;
        }
        if (m_fields->lastSafePlatform &&
            (!stepSurfaceTarget ||
             (stepSurfaceTarget->object != m_fields->lastSafePlatform &&
              stepSurfaceTarget->dx < -42.f))) {
            m_fields->lastSafePlatform = nullptr;
        }

        g_state.action = g_state.action.empty() ? "IDLE" : g_state.action;

        if (m_fields->hudLabel) {
            m_fields->hudLabel->setVisible(hudEnabled);
            if (hudEnabled) {
                const std::string hud = fmt::format(
                    "GEOPILOT {} | AUTO {} | MAP {} {:.1f}%\n"
                    "MAP H{} B{} O{} PORT{} SPD{} DASH{} PAD{} | FRAME {} FPS {:.0f}\n"
                    "SCAN {} objects / {} red / {} cyan / {} orb | LEAD {}f\n"
                    "PLAN {}\n"
                    "TARGET {} DIST {:.1f} ETA {} ORB {} | {}\nXP D{} A{} R{} / {}",
                    g_state.mode, enabled ? "ON" : "OFF",
                    g_state.mapReady ? "READY" : "SCAN", g_state.mapProgress,
                    g_state.mapHazards, g_state.mapSafeSurfaces, g_state.mapOrbs,
                    g_state.mapPortals, g_state.mapSpeedPortals, g_state.mapDashRings, g_state.mapPads, g_state.frame, g_state.fps,
                    g_state.scannedObjects, g_state.knownHazards, g_state.safeSurfaces,
                    g_state.recognizedOrbs, leadFrames,
                    g_state.routeSignal,
                    g_state.targetId < 0 ? "--" : std::to_string(g_state.targetId),
                    g_state.distance, etaText(g_state.framesToImpact),
                    g_state.orbTargetId < 0 ? "--" : std::string(orbName(g_state.orbTargetId)), g_state.action,
                    g_state.experienceDeaths, g_state.experienceAttempts,
                    g_state.experienceStreak, g_state.experienceHint
                );
                m_fields->hudLabel->setString(hud.c_str());
            }
        }

        if (mod->getSettingValue<bool>("show-debug-log") && m_fields->logTimer <= 0.f) {
            log::info("GeoPilot frame={} mode={} scan={} hazards={} target={} dist={:.1f} ETA={} action={}",
                g_state.frame, g_state.mode, g_state.scannedObjects, g_state.knownHazards,
                g_state.targetId, g_state.distance, etaText(g_state.framesToImpact), g_state.action);
            m_fields->logTimer = 1.f;
        }
    }

    void onQuit() {
        if (m_player1) m_player1->releaseAllButtons();
        if (m_fields->scanDraw) m_fields->scanDraw->clear();
        if (m_fields->hudLabel) m_fields->hudLabel->setVisible(false);
        g_state = RuntimeState{};
        PlayLayer::onQuit();
    }
};

class GeoPilotSettingsPopup : public geode::Popup {
protected:
    ButtonSprite* m_autoSprite = nullptr;
    ButtonSprite* m_orbSprite = nullptr;
    ButtonSprite* m_raysSprite = nullptr;
    ButtonSprite* m_hudSprite = nullptr;
    ButtonSprite* m_modeSprite = nullptr;
    ButtonSprite* m_leadSprite = nullptr;
    ButtonSprite* m_rangeSprite = nullptr;
    CCLabelBMFont* m_statusLabel = nullptr;

    bool init() {
        if (!Popup::init(420.f, 320.f, "square01_001.png")) return false;
        setTitle("GeoPilot Control Center");

        auto menu = CCMenu::create();
        menu->setPosition(CCPointZero);
        this->addChild(menu, 10);

        auto addButton = [&](const char* text, CCPoint pos, SEL_MenuHandler selector) -> ButtonSprite* {
            auto sprite = ButtonSprite::create(text, "bigFont.fnt", "GJ_button_04.png", 0.70f);
            if (!sprite) return nullptr;
            sprite->setScale(0.44f);
            auto item = CCMenuItemSpriteExtra::create(sprite, nullptr, this, selector);
            item->setPosition(pos);
            menu->addChild(item);
            return sprite;
        };

        auto logo = createGeoPilotLogo();
        if (logo) {
            logo->setScale(0.50f);
            logo->setPosition({34.f, 273.f});
            this->addChild(logo, 8);
        }

        auto subtitle = CCLabelBMFont::create("SCAN  /  PREDICT  /  ACT", "chatFont.fnt");
        if (subtitle) {
            subtitle->setScale(0.53f);
            subtitle->setAnchorPoint({0.f, 0.5f});
            subtitle->setPosition({61.f, 273.f});
            subtitle->setColor({100, 220, 255});
            this->addChild(subtitle, 8);
        }

        m_autoSprite = addButton("", {112.f, 224.f}, menu_selector(GeoPilotSettingsPopup::onToggleAuto));
        m_orbSprite = addButton("", {308.f, 224.f}, menu_selector(GeoPilotSettingsPopup::onToggleOrbs));
        m_raysSprite = addButton("", {112.f, 185.f}, menu_selector(GeoPilotSettingsPopup::onToggleRays));
        m_hudSprite = addButton("", {308.f, 185.f}, menu_selector(GeoPilotSettingsPopup::onToggleHud));
        m_modeSprite = addButton("", {112.f, 146.f}, menu_selector(GeoPilotSettingsPopup::onCycleMode));
        m_leadSprite = addButton("", {308.f, 146.f}, menu_selector(GeoPilotSettingsPopup::onCycleLead));
        m_rangeSprite = addButton("", {210.f, 107.f}, menu_selector(GeoPilotSettingsPopup::onCycleRange));

        m_statusLabel = CCLabelBMFont::create("", "chatFont.fnt");
        if (m_statusLabel) {
            m_statusLabel->setScale(0.30f);
            m_statusLabel->setPosition({210.f, 48.f});
            m_statusLabel->setColor({150, 225, 255});
            this->addChild(m_statusLabel, 8);
        }

        refreshLabels();
        return true;
    }

    void refreshLabels() {
        auto mod = Mod::get();
        if (m_autoSprite) m_autoSprite->setString(mod->getSettingValue<bool>("auto-play") ? "AUTO PLAY: ON" : "AUTO PLAY: OFF");
        if (m_orbSprite) m_orbSprite->setString(mod->getSettingValue<bool>("orb-assist") ? "ORB ASSIST: ON" : "ORB ASSIST: OFF");
        if (m_raysSprite) m_raysSprite->setString(mod->getSettingValue<bool>("show-rays") ? "SCAN RAYS: ON" : "SCAN RAYS: OFF");
        if (m_hudSprite) m_hudSprite->setString(mod->getSettingValue<bool>("show-hud") ? "HUD: ON" : "HUD: OFF");
        if (m_modeSprite) m_modeSprite->setString(fmt::format("MODE: {}", mod->getSettingValue<std::string>("control-mode")).c_str());
        if (m_leadSprite) m_leadSprite->setString(fmt::format("LEAD: {}F", mod->getSettingValue<int64_t>("lead-frames")).c_str());
        if (m_rangeSprite) m_rangeSprite->setString(fmt::format("SCAN RANGE: {}", mod->getSettingValue<int64_t>("reaction-distance")).c_str());

        if (m_statusLabel) {
            const std::string status = fmt::format(
                "MAP PRECHECK {} {:.1f}% | H{} B{} O{} P{} SPD{} DASH{} PAD{}\n"
                "NEXT: {}\nMODE {} FRAME {} FPS {:.0f}\n"
                "SCAN {} objects / {} red / {} cyan / {} orb\n"
                "TARGET {} ETA {} ORB {} ACTION {}\nXP D{} A{} R{} / {}",
                g_state.mapReady ? "READY" : "WAIT",
                g_state.mapProgress, g_state.mapHazards, g_state.mapSafeSurfaces,
                g_state.mapOrbs, g_state.mapPortals, g_state.mapSpeedPortals, g_state.mapDashRings, g_state.mapPads,
                g_state.routeSignal, g_state.mode, g_state.frame, g_state.fps,
                g_state.scannedObjects, g_state.knownHazards, g_state.safeSurfaces,
                g_state.recognizedOrbs,
                g_state.targetId < 0 ? "--" : std::to_string(g_state.targetId),
                etaText(g_state.framesToImpact),
                g_state.orbTargetId < 0 ? "--" : std::string(orbName(g_state.orbTargetId)),
                g_state.action, g_state.experienceDeaths, g_state.experienceAttempts,
                g_state.experienceStreak, g_state.experienceHint
            );
            m_statusLabel->setString(status.c_str());
        }
    }

public:
    static GeoPilotSettingsPopup* create() {
        auto ret = new GeoPilotSettingsPopup();
        if (ret->init()) {
            ret->autorelease();
            return ret;
        }
        delete ret;
        return nullptr;
    }

    void onToggleAuto(CCObject*) {
        auto mod = Mod::get();
        mod->setSettingValue<bool>("auto-play", !mod->getSettingValue<bool>("auto-play"));
        refreshLabels();
    }
    void onToggleOrbs(CCObject*) {
        auto mod = Mod::get();
        mod->setSettingValue<bool>("orb-assist", !mod->getSettingValue<bool>("orb-assist"));
        refreshLabels();
    }
    void onToggleRays(CCObject*) {
        auto mod = Mod::get();
        mod->setSettingValue<bool>("show-rays", !mod->getSettingValue<bool>("show-rays"));
        refreshLabels();
    }
    void onToggleHud(CCObject*) {
        auto mod = Mod::get();
        mod->setSettingValue<bool>("show-hud", !mod->getSettingValue<bool>("show-hud"));
        refreshLabels();
    }
    void onCycleMode(CCObject*) {
        auto mod = Mod::get();
        const std::vector<std::string> modes = {
            "Auto", "Cube", "Ship", "Ball", "UFO", "Wave", "Robot", "Spider", "Swing", "Platformer"
        };
        auto current = mod->getSettingValue<std::string>("control-mode");
        auto it = std::find(modes.begin(), modes.end(), current);
        const auto index = it == modes.end() ? size_t{0} :
            (static_cast<size_t>(std::distance(modes.begin(), it)) + 1) % modes.size();
        mod->setSettingValue<std::string>("control-mode", modes[index]);
        refreshLabels();
    }
    void onCycleLead(CCObject*) {
        auto mod = Mod::get();
        auto lead = mod->getSettingValue<int64_t>("lead-frames") + 1;
        if (lead > 10) lead = 2;
        mod->setSettingValue<int64_t>("lead-frames", lead);
        refreshLabels();
    }
    void onCycleRange(CCObject*) {
        auto mod = Mod::get();
        auto range = mod->getSettingValue<int64_t>("reaction-distance") + 50;
        if (range > 650) range = 250;
        mod->setSettingValue<int64_t>("reaction-distance", range);
        refreshLabels();
    }
};

class $modify(GeoPilotPauseLayer, PauseLayer) {
    void customSetup() {
        PauseLayer::customSetup();

        const auto win = CCDirector::sharedDirector()->getWinSize();
        auto logo = createGeoPilotLogo();
        if (!logo) {
            auto fallback = ButtonSprite::create("GEOPILOT", "bigFont.fnt", "GJ_button_04.png", 0.7f);
            fallback->setScale(0.50f);
            auto item = CCMenuItemSpriteExtra::create(
                fallback, nullptr, this, menu_selector(GeoPilotPauseLayer::onOpenSettings));
            auto menu = CCMenu::create();
            menu->setPosition({win.width - 42.f, win.height * 0.50f});
            menu->addChild(item);
            this->addChild(menu, 10);
            return;
        }

        logo->setScale(0.58f);
        auto item = CCMenuItemSpriteExtra::create(
            logo, nullptr, this, menu_selector(GeoPilotPauseLayer::onOpenSettings));
        item->setID("geopilot-settings-button");
        auto menu = CCMenu::create();
        menu->setPosition({win.width - 42.f, win.height * 0.50f});
        menu->addChild(item);
        this->addChild(menu, 10);

        auto label = CCLabelBMFont::create("GEOPILOT", "chatFont.fnt");
        if (label) {
            label->setScale(0.46f);
            label->setPosition({win.width - 42.f, win.height * 0.50f - 28.f});
            label->setColor({100, 220, 255});
            this->addChild(label, 10);
        }
    }

    void onOpenSettings(CCObject*) {
        if (auto popup = GeoPilotSettingsPopup::create()) popup->show();
    }
};
