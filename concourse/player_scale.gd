class_name PlayerScale
extends RefCounted
## The player-size reference used to judge the hall's dimensions (the red capsule in the
## test screenshots). If your player is a different size, change these and re-run
## the checks; the hall derives its rail height and stair headroom from them.

const HEIGHT := 1.8          # total capsule height (m)
const RADIUS := 0.25         # capsule radius (m); the player is 0.5 m wide
const JUMP_HEIGHT := 1.2     # how high the capsule's feet leave the ground in a jump
const HEADROOM_MARGIN := 1.0 # extra room wanted above a jumping player

const CHEST_HEIGHT := HEIGHT * 0.72   # about 1.3 m: balustrade top rail
const WAIST_HEIGHT := HEIGHT * 0.58   # about 1.05 m: counter tops
const WIDTH := RADIUS * 2.0
