pragma ComponentBehavior: Bound

import QtQuick
import QtQml.XmlListModel
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.I18n

// TODO: handle this better later

Item {
    id: model

    property alias visibleModel: visibleModel
    property string activeLabel: ""
    property int activeIndex: -1
    property var _xkbMap: ({})
    property bool _notifiedLimit: false

    function start() {
        xkbXml.source = "file://" + (Quickshell.env("CAELESTIA_XKB_RULES_PATH") || "/usr/share/X11/xkb/rules/base.lst").replace(/\.lst$/, ".xml");
        getKbLayoutOpt.running = true;
    }

    function refresh() {
        _notifiedLimit = false;
        getKbLayoutOpt.running = true;
    }

    function switchTo(idx) {
        switchProc.command = ["hyprctl", "switchxkblayout", "all", String(idx)];
        switchProc.running = true;
    }

    function _buildXmlMap() {
        const map = {};

        for (let i = 0; i < xkbXml.count; i++) {
            const code = xkbXml.data(xkbXml.index(i, 0), Qt.UserRole);
            const desc = xkbXml.data(xkbXml.index(i, 0), Qt.UserRole + 1);
            if (!code || !desc)
                continue;
            map[code] = _short(desc);
        }

        if (Object.keys(map).length === 0)
            return;

        _xkbMap = map;

        if (layoutsModel.count > 0) {
            const tmp = [];
            for (let i = 0; i < layoutsModel.count; i++) {
                const it = layoutsModel.get(i);
                tmp.push({
                    layoutIndex: it.layoutIndex,
                    token: it.token,
                    label: _pretty(it.token)
                });
            }
            layoutsModel.clear();
            tmp.forEach(t => layoutsModel.append(t));
            fetchActiveLayouts.running = true;
        }
    }

    function _short(desc) {
        const m = desc.match(/^(.*)\((.*)\)$/);
        if (!m)
            return desc;
        const lang = m[1].trim();
        const region = m[2].trim();
        const code = (region.split(/[,\s-]/)[0] || region).slice(0, 2).toUpperCase();
        // TRANSLATORS: %1 = language, %2 = layout code
        return Tr.trCtx("%1 (%2)", "keyboard layout language and code").arg(lang).arg(code);
    }

    function _setLayouts(raw) {
        const parts = raw.split(",").map(s => s.trim()).filter(Boolean);
        layoutsModel.clear();

        let idx = 0;

        for (const p of parts) {
            layoutsModel.append({
                layoutIndex: idx,
                token: p,
                label: _pretty(p)
            });
            idx++;
        }
    }

    function _rebuildVisible() {
        visibleModel.clear();

        let arr = [];
        for (let i = 0; i < layoutsModel.count; i++)
            arr.push(layoutsModel.get(i));

        arr = arr.filter(i => i.layoutIndex !== activeIndex);
        arr.forEach(i => visibleModel.append(i));

        if (!GlobalConfig.utilities.toasts.kbLimit)
            return;

        if (layoutsModel.count > 4) {
            Toaster.toast(Tr.tr("Keyboard layout limit"), Tr.tr("XKB supports only 4 layouts at a time"), "warning");
        }
    }

    function _pretty(token) {
        const code = token.replace(/\(.*\)$/, "").trim();
        if (_xkbMap[code])
            // TRANSLATORS: %1 = layout code, %2 = layout name
            return Tr.trCtx("%1 - %2", "keyboard layout code and name").arg(code.toUpperCase()).arg(_xkbMap[code]);
        // TRANSLATORS: %1 = layout code, %2 = layout name
        return Tr.trCtx("%1 - %2", "keyboard layout code and name").arg(code.toUpperCase()).arg(code);
    }

    visible: false

    ListModel {
        id: visibleModel
    }

    ListModel {
        id: layoutsModel
    }

    XmlListModel {
        id: xkbXml

        query: "/xkbConfigRegistry/layoutList/layout"
        XmlListModelRole { name: "code"; elementName: "configItem/name" }
        XmlListModelRole { name: "description"; elementName: "configItem/description" }

        onStatusChanged: {
            if (status === XmlListModel.Ready && count > 0) {
                model._buildXmlMap();
            } else if (status === XmlListModel.Error || status === XmlListModel.Ready) {
                if (source.toString().endsWith("/evdev.xml"))
                    console.warn("Failed to load XKB layout descriptions:", source, errorString());
                else
                    source = source.toString().replace(/[^/]+$/, "evdev.xml");
            }
        }
    }

    Process {
        id: getKbLayoutOpt

        command: ["hyprctl", "-j", "getoption", "input:kb_layout"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    const raw = (j?.str || j?.value || "").toString().trim();
                    if (raw.length) {
                        model._setLayouts(raw);
                        fetchActiveLayouts.running = true;
                        return;
                    }
                } catch (e) {}
                fetchLayoutsFromDevices.running = true;
            }
        }
    }

    Process {
        id: fetchLayoutsFromDevices

        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const dev = JSON.parse(text);
                    const kb = dev?.keyboards?.find(k => k.main) || dev?.keyboards?.[0];
                    const raw = (kb?.layout || "").trim();
                    if (raw.length)
                        model._setLayouts(raw);
                } catch (e) {}
                fetchActiveLayouts.running = true;
            }
        }
    }

    Process {
        id: fetchActiveLayouts

        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const dev = JSON.parse(text);
                    const kb = dev?.keyboards?.find(k => k.main) || dev?.keyboards?.[0];
                    const idx = kb?.active_layout_index ?? -1;

                    model.activeIndex = idx >= 0 ? idx : -1;
                    model.activeLabel = (idx >= 0 && idx < layoutsModel.count) ? layoutsModel.get(idx).label : "";
                } catch (e) {
                    model.activeIndex = -1;
                    model.activeLabel = "";
                }

                model._rebuildVisible();
            }
        }
    }

    Process {
        id: switchProc

        onExited: fetchActiveLayouts.running = true
    }
}
