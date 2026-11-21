import SwiftUI
import WidgetKit

@main
struct Peugeot408WidgetsBundle: WidgetBundle {
    var body: some Widget {
        CarSlot1()
        CarSlot2()
        CarSlot3()
        CarSlot4()
        CarSlot5()
        ServiceTrackerWidget()
        FuelLogWidget()
        RenewalsWidget()
        TouchNGoWidget()
        ParkingWidget()
        PrayerTimesWidget()
        CommuteWidget()
        WeatherHazeWidget()
        MapSnapshotWidget()
        PhotoFrameWidget()
        MusicWidget()
        #if !STORE_BUILD
        LyricsWidget()
        LyricsLiveActivity()
        #endif
        LiveOBDWidget()
        DriveLiveActivity()
    }
}
