jQuery(document).ready(function() {
    "use strict";    
    // Torture test: keep rerunning the tests over and over.
    plt.tests.initTests(function(runTests) {
        var k = function() {
            $("#is-running").text(
                "Tests finished.  " +
                    plt.tests.getTestsRunCount() + " tests executed."); 
            setTimeout(
                function() {
                    plt.tests.resetTests();
                    runTests(k);
                },
                0);
        };

        runTests(k);
    });
});

