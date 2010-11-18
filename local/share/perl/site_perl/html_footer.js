function tvis(id) {
    var e = document.getElementById(id);
    if (e.style.display == "block") {
        e.style.display = "none";
    } else {
        e.style.display = "block";
    }
    return true;
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
		if (anchorElems[i] && anchorElems[i].className == "outbound") {
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
                if (anchorElems[i] && anchorElems[i].className == "download") {
		    if (anchorElems[i].id) {
                        anchorElems[i].onclick = function () {
			    _gaq.push(['_trackEvent', 'download', this.id]);
                        }
		    }
                }
	    }
	}
    }
})();  // end of the outer closure
