from gpiozero import AngularServo
from time import sleep

SERVO_PIN = 12

def create_servo():
    return AngularServo(
        SERVO_PIN,
        min_angle=0,
        max_angle=180,
        min_pulse_width=0.0005,
        max_pulse_width=0.0025
    )

def dispense_food():
    servo = create_servo()

    print("Opening gate...")
    servo.angle = 90
    sleep(2)

    print("Closing gate...")
    servo.angle = 0
    sleep(1)

    servo.detach()
    print("Servo detached.")

if __name__ == "__main__":
    dispense_food()
