pragma Singleton

import Quickshell

Singleton {
    property var pendingRequests: []

    function get(url: string, success: var, failure: var, headers: var): void {
        pendingRequests.push({url, success, failure});
    }
}
