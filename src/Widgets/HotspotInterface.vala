/*-
 * Copyright (c) 2015-2016 elementary LLC.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Adam Bieńkowski <donadigos159@gmail.com>
 */

 namespace Network.Widgets {
    public class HotspotInterface : Network.AbstractHotspotInterface {

        private NM.RemoteSettings nm_settings;
        private Gtk.Revealer hotspot_revealer;
        private Gtk.Button hotspot_settings_btn;
        private Gtk.Label ssid_label;
        private Gtk.Label key_label;
        private bool switch_updating = false;

        public HotspotInterface (WifiInterface _root_iface) {
            root_iface = _root_iface;
            nm_settings = _root_iface.get_nm_settings ();
            info_box = new InfoBox.from_device (root_iface.device);
            this.init (root_iface.device, info_box);

            this.icon_name = "network-wireless-hotspot";

            hotspot_revealer = new Gtk.Revealer ();
            hotspot_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_DOWN;

            hotspot_settings_btn = Utils.get_advanced_button_from_device (device, _("Hotspot Settings…"));

            var hinfo_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);

            ssid_label = new Gtk.Label ("");
            ssid_label.halign = Gtk.Align.START;

            key_label = new Gtk.Label ("");
            key_label.halign = Gtk.Align.START;

            hinfo_box.add (ssid_label);
            hinfo_box.add (key_label);
            hotspot_revealer.add (hinfo_box);

            bottom_revealer = new Gtk.Revealer ();

            var button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            button_box.pack_end (hotspot_settings_btn, false, false, 0);
            bottom_revealer.add (button_box);

            nm_settings.connections_read.connect (update);
            device.state_changed.connect (update);

            update ();

            this.add (hotspot_revealer);
            this.pack_end (bottom_revealer, false, false);
            this.show_all ();
        }

        protected override void update () {
            if (hotspot_settings_btn != null) {
                hotspot_settings_btn.sensitive = Utils.Hotspot.get_device_is_hotspot (root_iface.wifi_device, root_iface.nm_settings);
            }

            update_hotspot_info ();
            update_switch ();
            base.update ();
        }

        protected override void update_switch () {
            switch_updating = true;
            control_switch.active = state == Network.State.CONNECTED_WIFI;
            switch_updating = false;
        }

        protected override void control_switch_activated () {
            if (switch_updating) {
                switch_updating = false;
                return;
            }

            var wifi_device = (NM.DeviceWifi)device;
            if (!control_switch.active && Utils.Hotspot.get_device_is_hotspot (wifi_device, nm_settings)) {
                Utils.Hotspot.deactivate_hotspot (wifi_device);
            } else {
                var hotspot_dialog = new HotspotDialog (wifi_device.get_active_access_point (), get_hotspot_connections ());
                hotspot_dialog.response.connect ((response) => {
                    if (response == 1) {
                        Utils.Hotspot.activate_hotspot (wifi_device,
                                            hotspot_dialog.get_ssid (),
                                            hotspot_dialog.get_key (),
                                            hotspot_dialog.get_selected_connection ());

                    } else {
                        switch_updating = true;
                        control_switch.active = false;
                    }              
                });

                hotspot_dialog.run ();
                hotspot_dialog.destroy ();
            }
        }

        private void update_hotspot_info () {
            var wifi_device = (NM.DeviceWifi)device;
            bool hotspot_mode = Utils.Hotspot.get_device_is_hotspot (wifi_device, nm_settings);

            var mode = Utils.CustomMode.HOTSPOT_DISABLED;
            if (hotspot_mode) {
                mode = Utils.CustomMode.HOTSPOT_ENABLED;
            }

            hotspot_revealer.set_reveal_child (hotspot_mode);

            if (hotspot_mode) {
                var connection = nm_settings.get_connection_by_path (wifi_device.get_active_connection ().get_connection ());

                var setting_wireless = connection.get_setting_wireless ();
                ssid_label.label = _("Network Name (SSID): %s").printf (NM.Utils.ssid_to_utf8 (setting_wireless.get_ssid ()));

                var setting_wireless_security = connection.get_setting_wireless_security ();

                string key_mgmt = setting_wireless_security.get_key_mgmt ();
                string? secret = null;
                string security = "";
                if (key_mgmt == "none") {
                    secret = setting_wireless_security.get_wep_key (0);
                    security = _("(WEP)");
                } else if (key_mgmt == "wpa-psk" ||
                            key_mgmt == "wpa-none") {
                    security = _("(WPA)");
                    secret = setting_wireless_security.get_psk ();
                }

                if (secret == null) {
                    Utils.Hotspot.update_secrets (connection, update);
                    return;
                }
                
                key_label.label = _("Password %s: %s").printf (security, secret);  
            }
        }

        private List<NM.Connection> get_hotspot_connections () {
            var list = new List<NM.Connection> ();
            var connections = nm_settings.list_connections ();

            foreach (var connection in connections) {
                if (Utils.Hotspot.get_connection_is_hotspot (connection)) {
                    list.append (connection);
                }
            }

            return list;
        }
    }
}