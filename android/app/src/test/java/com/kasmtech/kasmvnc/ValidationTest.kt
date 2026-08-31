package com.kasmtech.kasmvnc

import com.kasmtech.kasmvnc.domain.ServerValidator
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ValidationTest {
    @Test fun rejectsDangerousSchemes() {
        assertFalse(ServerValidator.validateUrl("javascript:alert(1)", true).valid)
        assertFalse(ServerValidator.validateUrl("file:///tmp/client", true).valid)
        assertFalse(ServerValidator.validateUrl("intent://settings", true).valid)
    }
    @Test fun requiresHttpsOutsideLocalDebug() {
        assertFalse(ServerValidator.validateUrl("http://remote.example", true).valid)
        assertTrue(ServerValidator.validateUrl("http://10.0.2.2:8080", true).valid)
        assertTrue(ServerValidator.validateUrl("https://remote.example", false).valid)
    }
    @Test fun restrictsNavigationToOriginHost() {
        assertTrue(ServerValidator.isAllowedNavigation("https://server.example/path", "https://server.example"))
        assertFalse(ServerValidator.isAllowedNavigation("https://evil.example", "https://server.example"))
    }
}
