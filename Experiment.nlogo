 ;==========================

; Row entry point:
; this is the point that a person stands at before they move
; into the seat-section of the row

globals [
  acceleration
  speed-limit

  radius-threshold ; the radius for a circle around a point, within which a person is considered to be on that point
  seat-offset ; the amount of x-dir distance from the middle of a patch to the seat point
  entry-offset ; the amount of x-dir distance from the middle of a patch to the seat entry point

  seat-leftmost-xcor
  seat-topmost-ycor
  isle-ycor
  primary-corridor-xcor

  starting-ycor
  starting-xcor

  ; List of numbers used to figure out where a person should wait
  ; when they have been asked to get out their seat
  ; to let another person in.
  ; Each element is the x-dir distance from the middle of a patch to the waiting point
  waiting-offsets
]

directed-link-breed [exiting-seat-links exiting-seat-link]
directed-link-breed [entering-seat-links entering-seat-link]

links-own [
  been-to-row-entry-point ; boolean to tell whether this person has been to the row entry point
]

breed [people-moving-to-row person-moving-to-row]
breed [people-moving-to-seat person-moving-to-seat]
breed [people-been-seated person-been-seated]
breed [people-at-starting-point person-at-starting-point]

turtles-own [
  speed
  seat-row
  seat-column

  ; The amount of time left till the person has packed their bag.
  ; Integer value is used and decremented on a tick.
  bag-pack-time-left
]

people-moving-to-row-own [
  heading-after-turn
]

people-been-seated-own [
  waiting-coords ; list of coords like [x y]
  waiting ; boolean to tell whether this person is waiting to get back in or not
]

patches-own [
  new-heading
  pseat-row
  pseat-column
]

;==========================
; Setup

to setup
  clear-all
  set-constants

  set-default-shape turtles "person"
  ;set-default-shape people-moving-to-seat "person"
  ;set-default-shape people-been-seated "person sitting"

  draw-map
  set-patch-seat-numbers
  create-people seat-numbers-for-strategy

  reset-ticks
end

to set-constants
  set acceleration 0.005
  set speed-limit 0.05
  set radius-threshold 0.05
  set seat-offset 0.2
  set entry-offset 0.25
  set waiting-offsets [0.3 0.05]

  set seat-leftmost-xcor 10
  set seat-topmost-ycor world-height - 5
  set isle-ycor seat-topmost-ycor - number-of-columns-per-side
  set primary-corridor-xcor round (seat-leftmost-xcor / 2)

  set starting-ycor 0
  set starting-xcor primary-corridor-xcor
end

;==========================
; Patch setup

to draw-map
  draw-background
  draw-airplane
  draw-primary-corridor
end

to draw-background
  ask patches [
    set pcolor green
    set new-heading false
  ]
end

to draw-airplane
  ask patches with [
    pxcor <= (seat-leftmost-xcor + number-of-rows - 1)
    and pxcor >= seat-leftmost-xcor
    and (
      (pycor <= seat-topmost-ycor and pycor > isle-ycor)
      or (pycor < isle-ycor and pycor >= isle-ycor - number-of-columns-per-side)
    )
  ] [set pcolor white]
  ask patches with [pxcor <= (seat-leftmost-xcor + number-of-rows - 1)
    and pxcor >= seat-leftmost-xcor
    and pycor = isle-ycor
  ] [set pcolor grey + 3]

  ; lines alongside the isle
  foreach (list (isle-ycor - 0.5) (isle-ycor + 0.5)) [ y ->
    draw-line (seat-leftmost-xcor - 0.5) y (seat-leftmost-xcor + number-of-rows - 0.5) y (red - 1) 0
  ]

  ; lines in between the rows
  foreach (n-values (number-of-rows - 1) [i -> seat-leftmost-xcor + i + 1]) [ x ->
    draw-line (x - 0.5) (seat-topmost-ycor + 0.5) (x - 0.5) (seat-topmost-ycor - number-of-columns-per-side + 0.5) black 0
    draw-line (x - 0.5) (seat-topmost-ycor - number-of-columns-per-side - 0.5) (x - 0.5) (seat-topmost-ycor - 2 * number-of-columns-per-side - 0.5) black 0
  ]

  ; lines in between columns
  foreach (n-values (number-of-columns-per-side - 1) [i -> seat-topmost-ycor - i - 0.5])[ y ->
    draw-line (seat-leftmost-xcor - 0.5) y (seat-leftmost-xcor + number-of-rows - 0.5) y (grey - 2) 0.5
  ]
  foreach (n-values (number-of-columns-per-side - 1) [i -> isle-ycor - i - 1.5])[ y ->
    draw-line (seat-leftmost-xcor - 0.5) y (seat-leftmost-xcor + number-of-rows - 0.5) y (grey - 2) 0.5
  ]
end

; The main corridor leading from the starting point into the airplane
to draw-primary-corridor
  ask patches with [pxcor = primary-corridor-xcor and pycor <= isle-ycor] [set pcolor grey]
  ask patches with [pxcor < seat-leftmost-xcor and pxcor > primary-corridor-xcor and pycor = isle-ycor] [set pcolor grey]
  ask patch primary-corridor-xcor isle-ycor [set new-heading 90]
  ask patch starting-xcor starting-ycor [set pcolor yellow]
end

; Draws a line from (x1, y1) to (x2, y2)
; A temporary turtle is used to draw the line.
; Gap = 0 gives a continuous line
; Gap = 0.5 gives a dashed line
to draw-line [x1 y1 x2 y2 line-color gap]
  create-turtles 1 [
    setxy x1 y1
    facexy x2 y2
    hide-turtle
    set color line-color
    while [distancexy x2 y2 >= 1] [
      pen-up
      forward gap
      pen-down
      forward (1 - gap)
    ]
    die
  ]
end

to set-patch-seat-numbers
  foreach (n-values number-of-rows [i -> i]) [ row ->
    foreach (n-values number-of-columns-per-side [i -> i]) [ column ->
      ask patch (seat-leftmost-xcor + row) (seat-topmost-ycor - column) [
        set pseat-row row + 1
        set pseat-column column + 1
      ]
      ask patch (seat-leftmost-xcor + row) (isle-ycor - column - 1) [
        set pseat-row row + 1
        set pseat-column column + 1 + number-of-columns-per-side
      ]
    ]
  ]
end

;==========================
; Seating strategies

to-report seat-numbers-for-strategy
  if strategy = "random" [report seats-in-random-order]
  if strategy = "back-to-front" [report seats-ordered-back-to-front]
  if strategy = "outside-in" [report seats-ordered-outside-in]
end

; Reports a list of lists with each element like [row column]
; All random
to-report seats-in-random-order
  let seat-numbers []
  foreach (n-values number-of-rows [i -> i + 1]) [ r ->
    foreach (n-values (2 * number-of-columns-per-side) [i -> i + 1]) [ c ->
      set seat-numbers lput (list (r) (c)) seat-numbers
    ]
  ]
  report shuffle seat-numbers
end

; Reports a list of lists with each element like [row column]
; columns ordered, rows random
to-report seats-ordered-outside-in
  let seat-numbers []
  foreach (n-values number-of-columns-per-side [i -> i + 1]) [ k ->
    let seat-number-block []
    let column-pair shuffle list (k) (2 * number-of-columns-per-side - k + 1)
    foreach (n-values number-of-rows [i -> i + 1]) [ r ->
      set seat-number-block lput (list (r) (item 0 column-pair)) seat-number-block
      set seat-number-block lput (list (r) (item 1 column-pair)) seat-number-block
    ]
    set seat-numbers sentence seat-numbers (shuffle seat-number-block)
  ]
  report seat-numbers
end

; Reports a list of lists with each element like [row column]
; rows ordered backwards, columns random
to-report seats-ordered-back-to-front
  let seat-numbers []
  foreach (reverse n-values number-of-rows [i -> i + 1]) [ r ->
    let column-numbers shuffle n-values (2 * number-of-columns-per-side) [i -> i + 1]
    foreach column-numbers [ c ->
      set seat-numbers lput (list (r) (c)) seat-numbers
    ]
  ]
  report seat-numbers
end

;==========================
; Turtle setup

; Expected seat-number to be a list of lists with each element like [row column]
to create-people [seat-numbers]
  foreach seat-numbers [ seat-number ->
    create-people-at-starting-point 1 [
      setxy starting-xcor starting-ycor
      if color = grey or color = white or color = grey + 3 or color = yellow [set color color + 2]
      set heading 0
      set speed 0
      set bag-pack-time-left 1
      set seat-row item 0 seat-number
      set seat-column item 1 seat-number
    ]
  ]
end

;==========================
; Actions (asks) for buttons

to go
  update-people-at-starting-point
  update-people-moving-to-row
  update-people-moving-to-seat
  update-people-been-seated
  relayer-turtles
  tick
end

;==========================
; Procedures for all turtles

to inc-speed
  set speed (speed + acceleration)
  if speed > speed-limit [set speed speed-limit]
end

;==========================
; Procedures for people-moving-to-seat & people-been-to-seat

; True if I am within range of coords.
; Expecting coords to be a list like [x y]
to-report close-to [coords]
  report distancexy (item 0 coords) (item 1 coords) < radius-threshold
end

; Move in the direction of coords.
; Expecting coords to be a list like [x y]
to forward-to [coords]
  face-toward coords
  inc-speed
  forward speed
end

; Face in the direction of coords.
; Expecting coords to be a list like [x y]
to face-toward [coords]
  facexy (item 0 coords) (item 1 coords)
end

; Move to the coords and stop moving.
; Expecting coords to be a list like [x y]
to latch-onto [coords]
  set speed 0
  setxy (item 0 coords) (item 1 coords)
end

; Notify next waiting person that they can move,
; change breeds, stop moving, move to seat point.
to sit-down
  hatch-people-been-seated 1 [
    latch-onto seat-coords
    if [any? my-out-links] of myself [
      create-entering-seat-link-to [one-of out-entering-seat-link-neighbors] of myself [hide-link]
    ]
    set shape "person sitting"
  ]
  die
end

;==========================
; Actions (asks) for people-moving-to-seat

to update-people-been-seated
  ask people-been-seated [
    ifelse any? my-in-exiting-seat-links [
      ; I need to move out of my seat and go to the waiting point

      ifelse close-to waiting-coords [ ; I am at the waiting point
        latch-onto waiting-coords
        set waiting true
      ][
        ; I am not at the waiting point yet

        ifelse [been-to-row-entry-point = true] of one-of my-in-exiting-seat-links [forward-to waiting-coords] [
          ; I have not been to the row entry point yet

          ifelse close-to row-entry-coords [ ; I am at the row entry point
            latch-onto row-entry-coords
            ask my-in-exiting-seat-links [set been-to-row-entry-point true]
          ][
            ; I am not at the row entry point yet

            ifelse not close-to seat-coords [forward-to row-entry-coords] [ ; I am not out of my seat yet
              set shape "person"
              latch-onto seat-entry-coords
            ]
          ]
        ]
      ]
    ][
      ; I am waiting or sitting

      if any? my-in-entering-seat-links [
        ; I need to move back to my seat
        set waiting false

        ifelse close-to seat-entry-coords [sit-down][
          ; I am not at the seat entry point yet

          ifelse [been-to-row-entry-point = true] of one-of my-in-entering-seat-links [forward-to seat-entry-coords] [
            ; I have not been to the row entry point yet

            ifelse not close-to row-entry-coords [forward-to row-entry-coords] [
              ; I am at the row entry point
              latch-onto row-entry-coords
              ask my-in-entering-seat-links [set been-to-row-entry-point true]
            ]
          ]
        ]
      ]
    ]
  ]
end

;==========================
; Actions (asks) for people-moving-to-seat

to update-people-moving-to-seat
  ask people-moving-to-seat [

    ifelse close-to seat-entry-coords [sit-down] [
      ; I am not at my seat yet

      ifelse bag-pack-time-left = 0 [
        ; my bag is packed

        if everyone-down-chain-waiting-for self [
          ; nobody is moving out of their seat for me

          let obstructing-person one-of search-for-obstructing-seated-people 1
          ifelse is-person-been-seated? obstructing-person [
            ; there is a person obstructing me from getting to my seat

            add-to-obstructing-chain obstructing-person
            let chain-length count-chain-items 0 self
            ask obstructing-person [
              set waiting-coords list (pxcor + item (chain-length - 1) waiting-offsets) ([ycor] of myself) ; these is just some hard-coded points
            ]
          ][
            ; nobody is obstructing me

            forward-to seat-entry-coords
          ]
        ]
      ][
        ; my bag is not packed

        ifelse not close-to row-entry-coords [forward-to row-entry-coords] [
          ; I am at the row-entry point

          latch-onto row-entry-coords
          dec-bag-counter
          face-toward seat-entry-coords ; we use this heading to check for obstructing persons
        ]
      ]
    ]
  ]
end

;==========================
; Procedures for people-moving-to-seat

; The number of people in the obstructing-people chain
to-report count-chain-items [current-count me]
  ifelse not any? [my-out-links] of me [report current-count] [
    report count-chain-items (current-count + 1) (one-of [out-link-neighbors] of me)
  ]
end

; Reports true if everyone in the obstructing-people chain is waiting
to-report everyone-down-chain-waiting-for [me]
  ifelse not any? [my-out-links] of me [report true] [
    ifelse any? ([out-link-neighbors] of me) with [waiting = true] [
      report everyone-down-chain-waiting-for one-of [out-link-neighbors] of me
    ] [report false]
  ]
end

; This method returns an agentset.
; The size of the set *should* be either 0 or 1.
; The set will contain a person who is obstructing the current person from getting to their seat.
; seats-ahead stores how many seats down the column we are currently looking at
; seats-ahead should initially be set to 1.
to-report search-for-obstructing-seated-people [seats-ahead]
  if seats-ahead >= limit [
    report turtles with [false] ; empty agentset
  ]
  ifelse any? turtles-on patch-at-heading-and-distance heading seats-ahead [
    report turtles-on patch-at-heading-and-distance heading seats-ahead
  ][
    report search-for-obstructing-seated-people (seats-ahead + 1)
  ]
end

; 1 + the number of seats inbetween the isle and my seat
to-report limit
  report distancexy xcor [pycor] of one-of patches with [
    pseat-row = [seat-row] of myself
    and
    pseat-column = [seat-column] of myself
  ]
end

; Add a person to the chain of obstructing people
to add-to-obstructing-chain [new-person]
  if any? out-link-neighbors [
    let next-person-in-chain one-of out-link-neighbors
    ask new-person [create-both-links-to next-person-in-chain]
    ask my-out-links [die]
  ]
  create-both-links-to new-person
end
to create-both-links-to [person]
  create-entering-seat-link-to person [hide-link]
  create-exiting-seat-link-to person [hide-link]
end

to dec-bag-counter
  set bag-pack-time-left (bag-pack-time-left - 1)
  if bag-pack-time-left < 0 [set bag-pack-time-left 0]
end

;==========================
; Actions (asks) for people-at-starting-point

to update-people-at-starting-point
  let people-to-move sort people-at-starting-point
  if not empty? people-to-move [
    ask first people-to-move [
      ifelse still-on-starting-patch [
        if close-to list (starting-xcor) (starting-ycor) or space-to-move [
          inc-speed
          forward speed
        ]
      ][
        hatch-people-moving-to-row 1 [set heading-after-turn false]
        die
      ]
    ]
  ]
end

; Reports true if the person is still on the starting point patch
to-report still-on-starting-patch
  report pycor = starting-ycor
end

;==========================
; Actions (asks) for people-moving-to-row

to update-people-moving-to-row
  ask people-moving-to-row [
    ifelse found-my-row [
      set speed 0
      if not any? other turtles-here [
        hatch-people-moving-to-seat 1
        die
      ]
    ][
      update-heading
      update-speed
      forward speed
      re-align
    ]
  ]
end

;==========================
; Procedures for people-moving-to-row

to-report found-my-row
  report (pxcor = [pxcor] of seat-patch) and pycor = isle-ycor
end

to update-heading
  ; if we are on a turning patch and we have not started turning
  if new-heading != false and heading-after-turn = false [
    set heading-after-turn new-heading
    set heading ((heading + new-heading) / 2)
  ]
  ; if we are not on a turning patch and we are still turning
  if new-heading = false and heading-after-turn != false [
    set heading heading-after-turn
    set heading-after-turn false
  ]
  ; otherwise we keep going in the same direction
end

to update-speed
  ifelse speed = 0 [
    if space-to-move [inc-speed]
  ][
    ifelse need-to-stop [set speed 0] [inc-speed]
  ]
end

to-report need-to-stop
  if any? people-been-seated-on patch-ahead 1 or any? people-moving-to-seat-on patch-ahead 1 [report true]
  report any? other turtles in-cone 0.5 90
end

to-report space-to-move
  report not any? other turtles in-cone 0.75 90
end

; After turning a person could be a little off-center on the patch.
; This method fixes that issue by slowly shifting the person back.
to re-align
  if new-heading = false and heading-after-turn = false [
    ; I am not turning

    let previous-heading heading
    ifelse heading = 90 or heading = 270 [
      ; I am moving horizontally

      ; if we are out of alignment
      ifelse abs (ycor - pycor) < radius-threshold [set ycor pycor] [
        facexy xcor pycor
        forward abs (pycor - ycor) / 2
      ]
    ][
      ; I am moving vertically

      ifelse abs (xcor - pxcor) < radius-threshold [set xcor pxcor] [
        facexy pxcor ycor
        forward abs (pxcor - xcor) / 2
      ]
    ]
    set heading previous-heading
  ]
end

;==========================
; Relayering
; These procedures make sure we have people drawn in the correct order
; so that they don't overlap in weird ways.

to relayer-turtles
  ask people-moving-to-row with [any? people-above-me and not any? people-below-me] [
    relayer-turtle
  ]
end

to-report people-above-me
  report person-at-heading 0
end

to-report people-below-me
  report person-at-heading 180
end

to-report person-at-heading [x]
  let previous-heading heading
  set heading x
  let result other people-moving-to-row in-cone 0.99 10
  set heading previous-heading
  report result
end

to relayer-turtle
  ask people-above-me [relayer-turtle]
  hatch 1
  die
end

;==========================
; Coords

; The patch where my seat is
to-report seat-patch
  report one-of patches with [
    pseat-row = [seat-row] of myself
    and
    pseat-column = [seat-column] of myself
  ]
end

; The coords of the place where a person moves to sitting position.
; Returns a list of coords like [x y]
to-report seat-coords
  report list (([pxcor] of seat-patch) + seat-offset) ([pycor] of seat-patch)
end

; The coords of the point that a person has to reach in order to sit down.
; Returns a list of coords like [x y]
to-report seat-entry-coords
  report list (([pxcor] of seat-patch) - entry-offset) ([pycor] of seat-patch)
end

; The coords of the point in the isle that is in the same row as a person's seat.
; Returns a list of coords like [x y]
to-report row-entry-coords
  report list (([pxcor] of seat-patch) - entry-offset) (isle-ycor)
end

;==========================
@#$#@#$#@
GRAPHICS-WINDOW
589
33
1502
414
-1
-1
17.76
1
10
1
1
1
0
0
0
1
0
50
0
20
1
1
1
ticks
30.0

BUTTON
11
154
77
187
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
13
205
76
238
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
245
154
417
187
number-of-rows
number-of-rows
1
32
7.0
1
1
NIL
HORIZONTAL

SLIDER
89
205
288
238
number-of-columns-per-side
number-of-columns-per-side
1
3
2.0
1
1
NIL
HORIZONTAL

SWITCH
93
73
239
106
multiple-entry
multiple-entry
1
1
-1000

CHOOSER
364
63
502
108
strategy
strategy
"random" "back-to-front" "outside-in"
2

SLIDER
295
297
535
330
percentage-people-with-bags
percentage-people-with-bags
1
100
39.0
1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

person sitting
false
0
Circle -7500403 true true 105 0 90
Polygon -7500403 true true 120 105 120 195 90 180 90 210 105 270 135 270 135 225 165 225 180 210 180 165 180 90
Rectangle -7500403 true true 135 79 172 105
Polygon -7500403 true true 135 90 75 150 90 180 165 90

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
