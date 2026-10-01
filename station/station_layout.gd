class_name StationLayout
extends RefCounted
## Where everything of the Central Station sits. The station frame has its origin at the hall's
## centre ON the hall floor; +X is east, +Z is south. World = HUB + frame (y: HALL_FLOOR_Y + frame y).

const HUB := Vector3(762.0, 3.75, 850.0)   # hall centre, world (y = hall floor)
const GROUND_Y := 3.0                      # terrain height all round the site
const STREET_Y := 3.15                     # road surface (ground + 0.15)

# the hall (8 bays of 8 m, 30 m wide); its end walls' OUTER faces are at +-HALL_END
const HALL_HALF_LEN := 32.0
const HALL_HALF_W := 15.0
const WALL_T := 1.0
const HALL_END := HALL_HALF_LEN + WALL_T           # 33
const HALL_SIDE := HALL_HALF_W + WALL_T            # 16: back face of the long walls

# east (main) facade and ticket hall
const FRONT_E := 49.0                              # front plane of the main facade
const FACADE_HALF := 42.5                          # facade spans z = +-42.5 (85 m)
const FACADE_H := 17.0                             # wall height of the middle section
const PAVILION_H := 21.0
const PAVILION_W := 14.0
const GATE_W := 10.0
const GATE_H := 14.0
const TICKET_CEILING := 4.5                        # ~2.5x the capsule: low on purpose
const TICKET_HALF_W := 5.0

# west portal (rear entrance)
const FRONT_W := -49.0
const PORTAL_HALF := 15.0
const PORTAL_H := 15.0

# the platform level
const PL_Y := -8.0                                 # platform floor, frame y (world -4.25)
const PL_CLEAR := 4.1                              # interior height (ceiling stays under the water plane at world y 0)

# forecourt (east of the facade)
const PLAZA_DEPTH := 64.0
const PLAZA_HALF := 42.5


static func to_world(p: Vector3) -> Vector3:
	return HUB + p
