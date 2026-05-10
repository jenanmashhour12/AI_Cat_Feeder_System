from gpiozero import AngularServo
from time import sleep

servo = AngularServo(
    12,
    min_angle=0,
    max_angle=180,
    min_pulse_width=0.0005,
    max_pulse_width=0.0025
)

print("Testing MG995 servo")

try:
    while True:
        print("0 degrees")
        servo.angle = 0
        sleep(2)

        print("90 degrees")
        servo.angle = 90
        sleep(2)

        print("180 degrees")
        servo.angle = 180
        sleep(2)

except KeyboardInterrupt:
    print("Stopping")
    servo.angle = None
