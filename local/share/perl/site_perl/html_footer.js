function tvis(id) {
    var e = document.getElementById(id);
    if (e.style.display == "block") {
        e.style.display = "none";
    } else {
        e.style.display = "block";
    }
    return false
}
(function() {
    if (document.getElementsByTagName) {
	var anchorElems = document.getElementsByTagName("a");
	if (anchorElems && anchorElems.length) {
            for (var i = 0; i < anchorElems.length; i++) {
		if (anchorElems[i] && anchorElems[i].className == "amzn") {
		    if (anchorElems[i].id) {
			anchorElems[i].onclick = function () {
			    _gaq.push(['_trackEvent', 'outbound-amzn', this.id]);
			}
		    }
		}
		if (anchorElems[i] && anchorElems[i].className == "dlhead") {
		    if (anchorElems[i].id) {
			anchorElems[i].onclick = function () {
			    return tvis(this.id + "-body");
			}
		    }
		}
		if (anchorElems[i] && anchorElems[i].className == "sedra-out") {
		    anchorElems[i].onclick = function () {
			var href = this.href;
			if (href && href.indexOf("http://") === 0) {
			    var slash = href.indexOf("/", 7);
			    if (slash > 7) {
				_gaq.push(['_trackEvent', 'outbound-article', href.substring(7, slash)]);
			    }
			}
		    }
		}
	    }
	}
	var exportElem = document.getElementById("export");
	if (exportElem) {
            var exportAnchors = exportElem.getElementsByTagName("a");
            if (exportAnchors && exportAnchors.length) {
		for (var i = 0; i < exportAnchors.length; i++) {
                    if (exportAnchors[i] && exportAnchors[i].className == "download") {
			if (exportAnchors[i].id) {
                            exportAnchors[i].onclick = function () {
				_gaq.push(['_trackEvent', 'download', this.id]);
                            }
			}
                    }
		}
            }
	}
    }
})();  // end of the outer closure
