package hri

import "core:fmt"
import "vendor:sdl2"
import mu "vendor:microui"

main :: proc() {
    app, success := app_create()
    if success != true {
        fmt.println("App did not start propperly")
    } else {
        app_run_loop(&app)
    }
}