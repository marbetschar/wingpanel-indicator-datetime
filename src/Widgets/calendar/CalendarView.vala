/*-
 * Copyright (c) 2011–2018 elementary, Inc. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Maxwell Barvian
 *              Corentin Noël <corentin@elementaryos.org>
 */

public class DateTime.Widgets.CalendarView : Gtk.Grid {
    public signal void day_double_click ();
    public signal void event_updates ();
    public signal void selection_changed (GLib.DateTime? new_date);

    public GLib.DateTime? selected_date { get; private set; }

    private Grid grid;
    private Gtk.Stack stack;
    private Gtk.Grid big_grid;

    construct {
        var label = new Gtk.Label (new GLib.DateTime.now_local ().format (_("%OB, %Y")));
        label.hexpand = true;
        label.margin_start = 6;
        label.xalign = 0;
        label.width_chars = 13;

        var provider = new Gtk.CssProvider ();
        provider.load_from_resource ("/io/elementary/desktop/wingpanel/datetime/ControlHeader.css");

        var label_style_context = label.get_style_context ();
        label_style_context.add_class ("header-label");
        label_style_context.add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var left_button = new Gtk.Button.from_icon_name ("pan-start-symbolic");
        var center_button = new Gtk.Button.from_icon_name ("office-calendar-symbolic");
        center_button.tooltip_text = _("Go to today's date");
        var right_button = new Gtk.Button.from_icon_name ("pan-end-symbolic");

        var box_buttons = new Gtk.Grid ();
        box_buttons.margin_end = 6;
        box_buttons.valign = Gtk.Align.CENTER;
        box_buttons.get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);
        box_buttons.add (left_button);
        box_buttons.add (center_button);
        box_buttons.add (right_button);

        big_grid = create_big_grid ();

        stack = new Gtk.Stack ();
        stack.add (big_grid);
        stack.show_all ();
        stack.expand = true;

        stack.notify["transition-running"].connect (() => {
            if (stack.transition_running == false) {
                stack.get_children ().foreach ((child) => {
                    if (child != stack.visible_child) {
                        child.destroy ();
                    }
                });
            }
        });

        column_spacing = 6;
        row_spacing = 6;
        margin_start = margin_end = 10;
        attach (label, 0, 0);
        attach (box_buttons, 1, 0);
        attach (stack, 0, 1, 2);

        var event_store = Calendar.Store.get_event_store ();
        event_store.notify["data-range"].connect (() => {
            label.label = event_store.month_start.format (_("%OB, %Y"));

            sync_with_store ();

            selected_date = null;
            selection_changed (selected_date);
        });

        left_button.clicked.connect (() => {
            event_store.change_month (-1);
        });

        right_button.clicked.connect (() => {
            event_store.change_month (1);
        });

        center_button.clicked.connect (() => {
            show_today ();
        });
    }

    private Gtk.Grid create_big_grid () {
        grid = new DateTime.Widgets.Grid ();
        grid.show_all ();

        grid.on_event_add.connect ((date) => {
            show_date_in_maya (date);
            day_double_click ();
        });

        grid.selection_changed.connect ((date) => {
            selected_date = date;
            selection_changed (date);
        });

        return grid;
    }

    public void show_today () {
        var event_store = Calendar.Store.get_event_store ();
        var task_store = Calendar.Store.get_task_store ();

        var today = Calendar.Util.date_time_strip_time (new GLib.DateTime.now_local ());
        var start = Calendar.Util.date_time_get_start_of_month (today);
        selected_date = today;
        if (!start.equal (event_store.month_start)) {
            event_store.month_start = start;
            task_store.month_start = start;
        }
        sync_with_store ();

        grid.set_focus_to_today ();
    }

    // TODO: As far as maya supports it use the Dbus Activation feature to run the calendar-app.
    public void show_date_in_maya (GLib.DateTime date) {
        var command = "io.elementary.calendar --show-day %s".printf (date.format ("%F"));

        try {
            var appinfo = AppInfo.create_from_commandline (command, null, AppInfoCreateFlags.NONE);
            appinfo.launch_uris (null, null);
        } catch (GLib.Error e) {
            var dialog = new Granite.MessageDialog.with_image_from_icon_name (
                _("Unable To Launch Calendar"),
                _("The program \"io.elementary.calendar\" may not be installed"),
                "dialog-error"
            );
            dialog.show_error_details (e.message);
            dialog.run ();
            dialog.destroy ();
        }
    }

    /* Sets the calendar widgets to the date range of the event store */
    private void sync_with_store () {
        var event_store = Calendar.Store.get_event_store ();

        if (grid.grid_range != null && (event_store.data_range.equals (grid.grid_range) || grid.grid_range.first_dt.compare (event_store.data_range.first_dt) == 0)) {
            grid.update_today ();
            return; // nothing else to do
        }

        GLib.DateTime previous_first = null;
        if (grid.grid_range != null)
            previous_first = grid.grid_range.first_dt;

        big_grid = create_big_grid ();
        stack.add (big_grid);

        grid.set_range (event_store.data_range, event_store.month_start);
        grid.update_weeks (event_store.data_range.first_dt, event_store.num_weeks);

        if (previous_first != null) {
            if (previous_first.compare (grid.grid_range.first_dt) == -1) {
                stack.transition_type = Gtk.StackTransitionType.SLIDE_LEFT;
            } else {
                stack.transition_type = Gtk.StackTransitionType.SLIDE_RIGHT;
            }
        }

        stack.set_visible_child (big_grid);
    }
}
