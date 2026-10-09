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
#include <Geode/binding/ButtonSprite.hpp>
#include <Geode/binding/CCMenuItemSpriteExtra.hpp>
#include <Geode/cocos/draw_nodes/CCDrawNode.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
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
        std::string mode = "Unknown";
        std::string action = "INITIALIZING";
        int targetId = -1;
        bool enabled = false;
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
            // Invisible spikes
            case 144: case 145: case 205: case 459:
            // Color and ice spikes
            case 177: case 178: case 179:
            case 216: case 217: case 218: case 458:
            // Common saw / blade objects
            case 740: case 741: case 742:
            case 1705: case 1706: case 1707:
            case 1708: case 1709: case 1710:
                return true;
            default:
                return false;
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
    };

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
        float lastTriggeredX = -100000.f;
        int lastTriggeredId = -1;
        float releaseCooldown = 0.f;
        bool releaseNextFrame = false;
        bool jumpHeld = false;
        bool rightHeld = false;
        float logTimer = 0.f;
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

        if (!player || player->m_isDead || m_isPaused) {
            if (m_fields->scanDraw) m_fields->scanDraw->clear();
            if (m_fields->hudLabel) m_fields->hudLabel->setVisible(false);
            if (player && player->m_isDead) {
                m_fields->previousNearest = nullptr;
                m_fields->lastTriggeredHazard = nullptr;
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
        g_state.distance = -1.f;
        g_state.framesToImpact = -1.f;
        g_state.targetId = -1;
        g_state.closingRate = 0.f;
        g_state.action = enabled ? "SCANNING" : "SCAN ONLY";

        std::vector<ScanTarget> targets;
        std::vector<ScanTarget> hazards;
        auto objects = geode::cocos::CCArrayExt<GameObject*>(m_objects);

        for (auto* object : objects) {
            if (!object || object == player || object->m_objectID < 0) continue;
            const CCPoint objectCenter = nodeCenterInParent(object, this);
            const float dx = objectCenter.x - playerCenter.x;
            const float dy = objectCenter.y - playerCenter.y;

            // Scan only the forward sector and nearby vertical band.
            if (dx < -35.f || dx > scanDistance || std::abs(dy) > 300.f) continue;

            ++g_state.scannedObjects;
            const bool hazard = isKnownHazard(object->m_objectID);
            if (hazard) ++g_state.knownHazards;

            ScanTarget target;
            target.object = object;
            target.point = objectCenter;
            target.dx = dx;
            target.dy = dy;
            target.hazard = hazard;
            target.contactDistance = dx - approximateHalfWidth(object) - approximateHalfWidth(player);
            targets.push_back(target);
            if (hazard && dx > -30.f) hazards.push_back(target);
        }

        std::sort(targets.begin(), targets.end(), [](ScanTarget const& a, ScanTarget const& b) {
            return a.dx < b.dx;
        });
        std::sort(hazards.begin(), hazards.end(), [](ScanTarget const& a, ScanTarget const& b) {
            return a.contactDistance < b.contactDistance;
        });

        ScanTarget const* nearestHazard = hazards.empty() ? nullptr : &hazards.front();

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
                    const auto lineColor = target.hazard ? red : blue;
                    draw->drawSegment(playerCenter, target.point, target.hazard ? 1.8f : 0.7f, lineColor);
                    if (target.hazard) {
                        draw->drawDot(target.point, 4.f, red);
                        const float halfW = std::clamp(approximateHalfWidth(target.object), 6.f, 26.f);
                        const auto size = target.object->getContentSize();
                        const float halfH = std::clamp(size.height * std::abs(target.object->getScaleY()) * 0.5f, 6.f, 26.f);
                        CCPoint tl{target.point.x - halfW, target.point.y + halfH};
                        CCPoint tr{target.point.x + halfW, target.point.y + halfH};
                        CCPoint bl{target.point.x - halfW, target.point.y - halfH};
                        CCPoint br{target.point.x + halfW, target.point.y - halfH};
                        draw->drawSegment(tl, tr, 1.0f, amber);
                        draw->drawSegment(tr, br, 1.0f, amber);
                        draw->drawSegment(br, bl, 1.0f, amber);
                        draw->drawSegment(bl, tl, 1.0f, amber);
                    }
                    ++rayCount;
                }

                if (nearestHazard) {
                    draw->drawSegment(playerCenter, nearestHazard->point, 2.4f, red);
                    draw->drawDot(playerCenter, 4.f, cyan);
                }
            }
        }

        // Controller decisions use ETA in update frames, not a fixed pixel-only threshold.
        if (enabled && mode == PilotMode::Platformer && !m_fields->rightHeld) {
            player->pushButton(PlayerButton::Right);
            m_fields->rightHeld = true;
        }

        if (!enabled) {
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
            const float steeringWindow = std::max(24.f, static_cast<float>(leadFrames * 3));
            const bool imminentHazard = nearestHazard && framesToImpact >= 0.f &&
                                         framesToImpact <= steeringWindow;
            if (imminentHazard) {
                // Use the nearest hazard's vertical lane only when it is approaching;
                // distant hazards should not cause the ship/wave to climb too early.
                wantHold = nearestHazard->dy < -8.f;
                g_state.action = wantHold ? "HOLD / CLIMB" : "RELEASE / DESCEND";
            } else {
                // In an open corridor, keep ship/wave near the midline instead of free-falling.
                const float midline = CCDirector::sharedDirector()->getWinSize().height * 0.52f;
                wantHold = playerCenter.y < midline - 18.f;
                g_state.action = wantHold ? "HOLD / CENTER" : "RELEASE / CENTER";
            }

            if (wantHold != m_fields->jumpHeld) {
                if (wantHold) player->pushButton(PlayerButton::Jump);
                else player->releaseButton(PlayerButton::Jump);
                m_fields->jumpHeld = wantHold;
            }
        } else if (nearestHazard && pulseControlMode(mode) &&
                   m_fields->releaseCooldown <= 0.f) {
            // ETA-only gating can deadlock when the game's velocity API reports a low
            // value during scroll/portal transitions. Keep a speed-scaled lead distance,
            // but enforce a minimum collision window so a visible spike still triggers.
            const float speedLeadDistance = closingPerFrame * static_cast<float>(leadFrames);
            const float triggerDistance = std::clamp(
                std::max(82.f, speedLeadDistance), 82.f, 190.f);
            const bool inTimingWindow =
                (framesToImpact >= 0.f && framesToImpact <= static_cast<float>(leadFrames)) ||
                nearestHazard->contactDistance <= triggerDistance;

            if (!inTimingWindow) {
                g_state.action = fmt::format("TRACK / ETA {} / NEED {:.0f}", etaText(framesToImpact), triggerDistance);
            } else {
                const bool sameHazard = nearestHazard->object == m_fields->lastTriggeredHazard;
            if (!sameHazard) {
                player->pushButton(PlayerButton::Jump);
                m_fields->releaseNextFrame = true;
                m_fields->releaseCooldown = 0.08f;
                m_fields->lastTriggeredHazard = nearestHazard->object;
                m_fields->lastTriggeredX = nearestHazard->point.x;
                m_fields->lastTriggeredId = nearestHazard->object->m_objectID;
                g_state.action = fmt::format("JUMP / {}F LEAD", leadFrames);
                } else {
                    g_state.action = "TARGET ALREADY TRIGGERED";
                }
            }
        } else if (enabled) {
            if (mode == PilotMode::Platformer) {
                g_state.action = nearestHazard
                    ? fmt::format("MOVE RIGHT / ETA {}", etaText(framesToImpact))
                    : "MOVE RIGHT / SEARCH";
            } else {
                g_state.action = nearestHazard ? fmt::format("TRACK / ETA {}", etaText(framesToImpact)) : "SEARCHING";
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

        g_state.action = g_state.action.empty() ? "IDLE" : g_state.action;

        if (m_fields->hudLabel) {
            m_fields->hudLabel->setVisible(hudEnabled);
            if (hudEnabled) {
                const std::string hud = fmt::format(
                    "GEOPILOT  {}  |  AUTO {}\nFRAME {}  FPS {:.0f}  DT {:.4f}s\n"
                    "SCAN {} objects / {} hazards  |  LEAD {}f\n"
                    "TARGET {}  DIST {:.1f}  ETA {}  |  {}",
                    g_state.mode, enabled ? "ON" : "OFF",
                    g_state.frame, g_state.fps, g_state.dt,
                    g_state.scannedObjects, g_state.knownHazards, leadFrames,
                    g_state.targetId < 0 ? "--" : std::to_string(g_state.targetId),
                    g_state.distance, etaText(g_state.framesToImpact), g_state.action
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

class $modify(GeoPilotPauseLayer, PauseLayer) {
    struct Fields {
        ButtonSprite* autoSprite = nullptr;
        ButtonSprite* raysSprite = nullptr;
        ButtonSprite* hudSprite = nullptr;
        ButtonSprite* leadSprite = nullptr;
        CCLabelBMFont* statusLabel = nullptr;
    };

    void customSetup() {
        PauseLayer::customSetup();

        auto mod = Mod::get();
        const auto win = CCDirector::sharedDirector()->getWinSize();
        auto menu = CCMenu::create();
        menu->setPosition({win.width - 112.f, win.height - 48.f});
        menu->setID("geopilot-pause-controls");

        auto makeButton = [&](const char* text, const char* bg, SEL_MenuHandler callback) {
            auto sprite = ButtonSprite::create(text, "bigFont.fnt", bg, 0.6f);
            if (!sprite) return static_cast<CCMenuItemSpriteExtra*>(nullptr);
            sprite->setScale(0.50f);
            auto button = CCMenuItemSpriteExtra::create(sprite, this, callback);
            return button;
        };

        m_fields->autoSprite = ButtonSprite::create(
            mod->getSettingValue<bool>("auto-play") ? "AUTO PLAY: ON" : "AUTO PLAY: OFF",
            "bigFont.fnt", mod->getSettingValue<bool>("auto-play") ? "GJ_button_03.png" : "GJ_button_01.png", 0.6f);
        m_fields->autoSprite->setScale(0.50f);
        auto autoButton = CCMenuItemSpriteExtra::create(
            m_fields->autoSprite, this, menu_selector(GeoPilotPauseLayer::onToggleAuto));
        autoButton->setPosition({0.f, 0.f});
        menu->addChild(autoButton);

        m_fields->raysSprite = ButtonSprite::create(
            mod->getSettingValue<bool>("show-rays") ? "SCAN RAYS: ON" : "SCAN RAYS: OFF",
            "bigFont.fnt", mod->getSettingValue<bool>("show-rays") ? "GJ_button_03.png" : "GJ_button_01.png", 0.6f);
        m_fields->raysSprite->setScale(0.50f);
        auto raysButton = CCMenuItemSpriteExtra::create(
            m_fields->raysSprite, this, menu_selector(GeoPilotPauseLayer::onToggleRays));
        raysButton->setPosition({0.f, -34.f});
        menu->addChild(raysButton);

        m_fields->hudSprite = ButtonSprite::create(
            mod->getSettingValue<bool>("show-hud") ? "HUD: ON" : "HUD: OFF",
            "bigFont.fnt", mod->getSettingValue<bool>("show-hud") ? "GJ_button_03.png" : "GJ_button_01.png", 0.6f);
        m_fields->hudSprite->setScale(0.50f);
        auto hudButton = CCMenuItemSpriteExtra::create(
            m_fields->hudSprite, this, menu_selector(GeoPilotPauseLayer::onToggleHud));
        hudButton->setPosition({0.f, -68.f});
        menu->addChild(hudButton);

        const int lead = static_cast<int>(mod->getSettingValue<int64_t>("lead-frames"));
        m_fields->leadSprite = ButtonSprite::create(
            fmt::format("JUMP LEAD: {}F", lead).c_str(), "bigFont.fnt", "GJ_button_02.png", 0.6f);
        m_fields->leadSprite->setScale(0.50f);
        auto leadButton = CCMenuItemSpriteExtra::create(
            m_fields->leadSprite, this, menu_selector(GeoPilotPauseLayer::onCycleLead));
        leadButton->setPosition({0.f, -102.f});
        menu->addChild(leadButton);

        this->addChild(menu, 10);

        const auto status = fmt::format(
            "MODE: {}\nFRAME: {}  FPS: {:.0f}\nDT: {:.4f}s  SPEED: {:.2f}px/f\n"
            "TARGET ID: {}\nDIST: {:.1f}  ETA: {}\nSCAN: {} objects / {} hazards\nACTION: {}",
            g_state.mode, g_state.frame, g_state.fps, g_state.dt, g_state.closingRate,
            g_state.targetId < 0 ? "--" : std::to_string(g_state.targetId),
            g_state.distance, etaText(g_state.framesToImpact),
            g_state.scannedObjects, g_state.knownHazards, g_state.action
        );
        m_fields->statusLabel = CCLabelBMFont::create(status.c_str(), "chatFont.fnt");
        if (m_fields->statusLabel) {
            m_fields->statusLabel->setAnchorPoint({1.f, 1.f});
            m_fields->statusLabel->setPosition({win.width - 16.f, win.height - 196.f});
            m_fields->statusLabel->setScale(0.58f);
            m_fields->statusLabel->setColor({160, 230, 255});
            this->addChild(m_fields->statusLabel, 10);
        }
    }

    void onToggleAuto(CCObject*) {
        auto mod = Mod::get();
        const bool next = !mod->getSettingValue<bool>("auto-play");
        mod->setSettingValue<bool>("auto-play", next);
        if (m_fields->autoSprite) m_fields->autoSprite->setString(next ? "AUTO PLAY: ON" : "AUTO PLAY: OFF");
        geode::Notification::create(next ? "GeoPilot Auto Play ON" : "GeoPilot Auto Play OFF",
            next ? geode::NotificationIcon::Success : geode::NotificationIcon::Warning, 1.5f)->show();
    }

    void onToggleRays(CCObject*) {
        auto mod = Mod::get();
        const bool next = !mod->getSettingValue<bool>("show-rays");
        mod->setSettingValue<bool>("show-rays", next);
        if (m_fields->raysSprite) m_fields->raysSprite->setString(next ? "SCAN RAYS: ON" : "SCAN RAYS: OFF");
    }

    void onToggleHud(CCObject*) {
        auto mod = Mod::get();
        const bool next = !mod->getSettingValue<bool>("show-hud");
        mod->setSettingValue<bool>("show-hud", next);
        if (m_fields->hudSprite) m_fields->hudSprite->setString(next ? "HUD: ON" : "HUD: OFF");
    }

    void onCycleLead(CCObject*) {
        auto mod = Mod::get();
        int lead = static_cast<int>(mod->getSettingValue<int64_t>("lead-frames"));
        lead += 2;
        if (lead > 24) lead = 4;
        mod->setSettingValue<int64_t>("lead-frames", lead);
        if (m_fields->leadSprite) m_fields->leadSprite->setString(fmt::format("JUMP LEAD: {}F", lead).c_str());
    }
};
