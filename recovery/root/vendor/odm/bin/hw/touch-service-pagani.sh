#!/system/bin/sh
# pagani (24821) touch: run the Android 15 .302 recovery touch service with
# its own .302 libraries so shared ODM libs used by other models stay intact.
export LD_LIBRARY_PATH=/odm/touch302/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
exec /odm/touch302/bin/hw/vendor-oplus-hardware-touch-V2-service "$@"
