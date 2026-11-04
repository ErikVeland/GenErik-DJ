# Closed/front one-deck implementation plan

> **For agentic workers:** Use superpowers:executing-plans in this chat. Erik authorised the change directly. Do not use parallel agents.

**Goal:** Show one full-width deck on the closed/front phone screen, with quick A/B selection and direct Songs/Suggestions access.

**Architecture:** Add a front-only workspace behind the R42 presentation rule. Retain both existing deck views and independent front-screen panel state. Expose only the selected deck to touch and accessibility. Keep the existing wide workspace as the other branch.

**Tech stack:** SwiftUI, iOS 17, existing renderer commands and production-source Swift checks.

**Spec:** Erik's 4 November request in this chat and R28. One deck at a time, quick A/B switching, easy song/recommendation access. Preserve iPad and Duo inside layouts.

## Global constraints

- Keep R42's phone/window-width rule. Never select the front workspace by portrait orientation alone.
- Do not change audio, analysis, the existing wide browser, the wide dock or wide workspace geometry.
- Switching decks changes view selection only. It must not load, stop, play or seek.
- Show both deck names and playback status. Keep the selected deck's transport and crossfader reachable while browsing.
- Keep native touch cancellation and manual preparation. Cancel retired deck contacts on selection changes.
- Keep Songs and Suggestions searches/scroll positions separate. Suggestions identify the selected destination deck.
- Build once with the shared cache and deploy only to Duo, allowing extra Wi-Fi transfer time. Do not operate the iPad.

## Review focus

1. An old finger release cannot operate the newly selected deck.
2. Both decks retain loaded tracks, playback and front-only panel state.
3. Library resizing cannot cover the selector, selected-deck controls or crossfader.
4. Source/details/loading actions must fit the phone width.
5. iPad and inside-screen source paths remain unchanged.

## Task 1: Front workspace and navigation

**Files:** Add FrontPerformanceLayout.swift for selection/contact identity, bounded geometry and browser extent state. Add FrontPerformanceView.swift for the selector, retained deck views and persistent controls. Update only the front branch in ReplicaView.swift and make its existing DeckView available to the new view. Extend FrontBrowserView.swift with direct tab requests and compact song/loading rows. Let TouchFader accept an optional horizontal height with its existing default unchanged.

- [x] Write and run focused failing selection, geometry, panel cancellation and scope checks.
- [x] Implement the front state and view. Reuse existing deck and playback actions.
- [x] Wire front Songs/Suggestions requests and fit the loading shelf to phone width.
- [x] Run focused checks and review preservation of the wide workspace/browser/dock.
- [x] Commit, integrate, build once, verify runtime/signing and deploy to Duo only.
- [x] Record the exact source, numbered build and pending touch/audio acceptance. Stop device actions after launch.

## Execution ruling

The shared integration checkout contains unrelated uncommitted R43 work. Build this committed front-only source in its isolated workspace. Link to the single existing device cache and saved-app directory. Do not include or alter the R43 work. Integrate the front commits without replacing that work.

## Handover

Saved build 97, source fd13c60a7, installed on Duo. The launch request was accepted. No iPad operation occurred. Front touch, folding and audio acceptance remain pending.
