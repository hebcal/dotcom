function hcEsc(s) {
    if (typeof encodeURIComponent == "function") {
	return encodeURIComponent(s);
    } else {
	return escape(s);
    }
}

function hcImg(n) {
    var img = new Image(1,1), dt = new Date(), ref = document.referrer;
    var src = "/i/black-1x1.gif?n=" + n + ";t=" + dt.getTime();
    if (ref && ref.substring(0,4).toLowerCase() == "http") {
	src += ";r=" + hcEsc(ref);
    }
    img.src = src;
}

if (document.getElementsByTagName) {
    var f = document.getElementsByTagName("form");
    if (f && f.length) {
	for (var i = 0; i < f.length; i++) {
	    if (f[i] && f[i].className == "paypal") {
		if (f[i].id) {
		    f[i].onclick = function() {
			hcImg(this.id);
			urchinTracker("/paypal/" + this.id);
		    }
		}
	    }
	}
    }
}
