/*
 * $Id$
 * $URL$
 *
 * Copyright (c) 2010  Michael J. Radwin.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or
 * without modification, are permitted provided that the following
 * conditions are met:
 *
 *  * Redistributions of source code must retain the above
 *    copyright notice, this list of conditions and the following
 *    disclaimer.
 *
 *  * Redistributions in binary form must reproduce the above
 *    copyright notice, this list of conditions and the following
 *    disclaimer in the documentation and/or other materials
 *    provided with the distribution.
 *
 *  * Neither the name of Hebcal.com nor the names of its
 *    contributors may be used to endorse or promote products
 *    derived from this software without specific prior written
 *    permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
 * CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
(function() {
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
			    _gaq.push(['_trackEvent', 'paypal', this.id]);
			}
		    }
		}
	    }
	}
    }
})();  // end of the outer closure
