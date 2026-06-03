import { application } from "controllers/application"
import AlertSnapshotController from "controllers/alert_snapshot_controller"
import CameraFeedController from "controllers/camera_feed_controller"
import ChatController from "controllers/chat_controller"
import DashboardLayoutController from "controllers/dashboard_layout_controller"
import DashboardModalController from "controllers/dashboard_modal_controller"
import DashboardQuickAddController from "controllers/dashboard_quick_add_controller"
import DashboardSectionController from "controllers/dashboard_section_controller"
import DashboardSyncController from "controllers/dashboard_sync_controller"
import HelloController from "controllers/hello_controller"
import IntegrationPanelController from "controllers/integration_panel_controller"
import RunStreamController from "controllers/run_stream_controller"
import SquareGridController from "controllers/square_grid_controller"
import WidgetPickerController from "controllers/widget_picker_controller"

application.register("alert-snapshot", AlertSnapshotController)
application.register("camera-feed", CameraFeedController)
application.register("chat", ChatController)
application.register("dashboard-layout", DashboardLayoutController)
application.register("dashboard-modal", DashboardModalController)
application.register("dashboard-quick-add", DashboardQuickAddController)
application.register("dashboard-section", DashboardSectionController)
application.register("dashboard-sync", DashboardSyncController)
application.register("hello", HelloController)
application.register("integration-panel", IntegrationPanelController)
application.register("run-stream", RunStreamController)
application.register("square-grid", SquareGridController)
application.register("widget-picker", WidgetPickerController)
