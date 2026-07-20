# Game Rules

This file is the single source of truth for the game's rules. Edit it
whenever the rules change — the app should be kept in sync with whatever
is written here.

## Deck

- 4 colours (suits). Each colour has 12 cards: **2 to King** (no Aces) —
  2, 3, 4, 5, 6, 7, 8, 9, 10, Jack, Queen, King.
- 22 **trump** cards, numbered **0 to 21**. Trumps have no colour.
- Total: 4 × 12 + 22 = **70 cards**.

## Board layout

- **11 columns** in the tableau. The **middle column (6th)** starts empty.
- The other 10 columns are dealt an equal number of cards at random:
  70 cards ÷ 10 columns = **7 cards per column**.
- All cards are dealt face up and stay visible at all times — stacking is
  offset vertically (like a cascade) so every card's colour/number stays
  readable, nothing is ever hidden face-down.
- Within a column, cards are stacked with the first-dealt card at the top
  of the visual stack and each later card cascading below it. The
  **last card in a column (visually at the bottom) is the "apparent" /
  active card** — the one available to move or drag.

## Objective

Get rid of all 70 cards by moving them into the receiving slots at the
top of the screen.

## Receiving slots (7 total)

1. **Bottom Trump Slot** — builds trumps **up** starting from 0.
2. **Top Trump Slot** — builds trumps **down** starting from 21.
3. **Colour Slot** (×4, one per colour) — builds that colour **up**
   starting from 2 through King.
4. **Reserve Slot** — holds **exactly one card**, of any kind. You can
   never stack on the Reserve. It can be emptied by moving its card into
   an open tableau slot (see below), or by the automatic rules sending it
   to a foundation.

## Automatic moves

Cards can leave the tableau or the Reserve automatically, without the
player dragging them, whenever they are "apparent" (i.e. the active card
at the bottom of a tableau column, or the card sitting in the Reserve).

Trumps and colour cards are checked the same way for **when** this
happens: nothing auto-moves while a card is still actively mid-drag.
The check only runs once the currently-dragged card has been **dropped
somewhere** — into a tableau column, into the Reserve, or into one of the
foundation slots — no matter where it lands.

### Trumps

- An apparent trump **0** always auto-moves to the Bottom Trump Slot.
- An apparent trump **21** always auto-moves to the Top Trump Slot.
- An apparent trump auto-moves to the **Bottom Trump Slot** whenever its
  number is exactly **one more** than the current top card of the Bottom
  Trump Slot.
- An apparent trump auto-moves to the **Top Trump Slot** whenever its
  number is exactly **one less** than the current top card of the Top
  Trump Slot.

### Colour cards

- An apparent **2** of a colour always auto-moves to that colour's slot.
- An apparent card of rank *N* (N > 2) in a colour auto-moves to that
  colour's slot whenever the slot's current top card is rank *N − 1*.
- Colour auto-moves are **suspended** entirely whenever there is a card
  in the Reserve. They resume only once the Reserve's card has been
  placed into a free tableau slot (an empty column).

### Reserve

- The card sitting in the Reserve is itself "apparent" and is checked
  against the same auto-move rules above (trump or colour) as any
  tableau card.

## Manual moves (dragging)

### What grabbing a card picks up

A column may hold a **run**: a chain of consecutive-rank cards, either all
the same colour or all trumps, ending at the apparent card. Which exact
card you grab determines what moves:

- Grabbing the **apparent (bottom-most) card** of a column, or the card
  in the **Reserve**, always picks up **just that one card** — even if
  it's part of a longer run.
- Grabbing the card at the **top of a run** (the far end of the chain,
  i.e. the first card of the run, the one furthest from the apparent
  card) picks up **the whole run together**, down through the apparent
  card.
- Grabbing **any other card** — one in the middle of a run, or a buried
  card that isn't part of one — **isn't a valid grab**; nothing happens.

If the apparent card doesn't chain with anything above it, it has no run
of its own — the "top of the run" and "the apparent card" are the same
card, and grabbing it always just takes that single card.

### Where it can be dropped

- A single card (or a run) may be dropped:
  - onto an **empty tableau column** (any card, or any run, may go
    there), or
  - **on top of another apparent card**, if that target card is of the
    same kind and **exactly one rank away** ("just above or below") from
    the card you grabbed:
    - a **colour card** can only be placed on another card of the
      **same colour**, one rank higher or lower.
    - a **trump** can only be placed on another **trump**, one number
      higher or lower.
  - The Reserve and the foundation slots only ever accept a **single**
    card, never a run.

### Dragging a run inverts it

**Dragging a run is not its own move — it's a shortcut for doing the
single-card move above once per card, in sequence, starting from the
apparent card** (which is why only the apparent card and the top of the
run are valid grab points: those are the two ends a real one-by-one move
would start from). That has a real consequence for how the run lands: the
apparent card is placed *first* against the destination, so it ends up at
the *bottom* of the new stack; each card above it in the original column
then lands on top of the previous one, in order. The net effect is that
the run is **inverted** at the destination — the card that was the
apparent/bottom card of the source column becomes buried at the bottom
of the destination stack, and the card that was at the top of the run
(the one you actually grabbed to move the whole thing) becomes the new
apparent card at the destination.

## Open questions / assumptions to confirm

These are implementation assumptions made while transcribing the rules —
flag if any are wrong so this file (and the game) can be corrected:

- "Just above or below" for stacking is read as **rank differs by
  exactly 1**, in either direction (so building runs can go up or down
  freely, unlike classic solitaire's single-direction rule).
- "A free slot in the tableau" for emptying the Reserve is read as any
  **empty column** (including the middle column once it's been vacated
  again, or any column fully cleared during play).
