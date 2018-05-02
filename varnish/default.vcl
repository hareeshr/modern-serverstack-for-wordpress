vcl 4.0;
import std;

backend default {
		.host = "127.0.0.1";
		.port = "8080"; # READ THIS: You should configure Apache to run on port
}
acl purge {
	"localhost";
	"127.0.0.1";
}
sub purge_regex {
	ban("obj.http.X-Req-URL ~ " + req.url + " && obj.http.X-Req-Host == " + req.http.host);
}
sub purge_exact {
	ban("obj.http.X-Req-URL == " + req.url + " && obj.http.X-Req-Host == " + req.http.host);
}
sub purge_page {
	set req.url = regsub(req.url, "\?.*$", "");
	ban("obj.http.X-Req-URL-Base == " + req.url + " && obj.http.X-Req-Host == " + req.http.host);
}
sub vcl_recv {

	if (req.method == "PURGE") {
		if (client.ip !~ purge) {
			return(synth(405,"Not allowed."));
		}

		if (req.http.X-Purge-Method) {
			if (req.http.X-Purge-Method ~ "(?i)regex") {
				call purge_regex;
			} elsif (req.http.X-Purge-Method ~ "(?i)exact") {
				call purge_exact;
			} else {
				call purge_page;
			}
		} else {
			# No X-Purge-Method header was specified.
			# Do our best to figure out which one they want.
			if (req.url ~ "\.\*" || req.url ~ "^\^" || req.url ~ "\$$" || req.url ~ "\\[.?*+^$|()]") {
				call purge_regex;
			} elsif (req.url ~ "\?") {
				call purge_exact;
			} else {
				call purge_page;
			}
		}
		return(synth(200,"Purged."));
	}


  #http to https and www redirect
  if ((client.ip != "127.0.0.1" && std.port(server.ip) == 80) && (req.http.host ~ "^(?i)(www\.)?example.com")) {
    set req.http.x-redir = "https://" + req.http.host + req.url;
    return (synth(750, ""));
  }
#forward ip
 if (req.http.x-forwarded-for) {
   set req.http.X-Forwarded-For = req.http.X-Real-Ip;
  } else {
   set req.http.X-Forwarded-For = client.ip;
  }
	if (req.http.Accept-Encoding) {
		if (req.url ~ "\.(gif|jpg|jpeg|webp|swf|flv|mp3|mp4|pdf|ico|png|gz|tgz|bz2)(\?.*|)$") {
			unset req.http.Accept-Encoding;
		} elsif (req.http.Accept-Encoding ~ "gzip") {
			set req.http.Accept-Encoding = "gzip";
		} elsif (req.http.Accept-Encoding ~ "deflate") {
			set req.http.Accept-Encoding = "deflate";
		} else {
			unset req.http.Accept-Encoding;
		}
	}
	if (req.url ~ "\.(gif|jpg|jpeg|swf|webp|css|js|flv|mp3|mp4|pdf|ico|png)(\?.*|)$") {
		unset req.http.cookie;
		set req.url = regsub(req.url, "\?.*$", "");
	}
	if (req.url ~ "\?(utm_(campaign|medium|source|term)|adParams|client|cx|eid|fbid|feed|ref(id|src)?|v(er|iew))=") {
		set req.url = regsub(req.url, "\?.*$", "");
	}
	if (req.http.cookie) {
		if (req.http.cookie ~ "(wordpress_|wp-settings-)") {
			return(pass);
		} else {
			unset req.http.cookie;
		}
	}
}

sub vcl_backend_response {

	if (bereq.url ~ "wp-(login|admin|cron)" || bereq.url ~ "preview=true" || bereq.url ~ "xmlrpc.php" || bereq.url ~ "feed/" || bereq.url ~ "sitemap.xml" || bereq.url ~ "robots.txt") {
		set beresp.uncacheable = true;
		set beresp.ttl = 120s;
		return (deliver);
	}
	if ( (!(bereq.url ~ "(wp-(login|admin)|login)")) || (bereq.method == "GET") ) {
		unset beresp.http.set-cookie;
	}
	if (bereq.url ~ "\.(gif|jpg|jpeg|webp|swf|css|js|flv|mp3|mp4|pdf|ico|png|woff2|woff|eot|svg|ttf)(\?.*|)$") {
                set beresp.uncacheable = true;
                set beresp.ttl = 120s;
                return (deliver);
	}
       set beresp.http.X-Req-Host = bereq.http.host;
       set beresp.http.X-Req-URL = bereq.url;
       set beresp.http.X-Req-URL-Base = regsub(bereq.url, "\?.*$", "");

}

sub vcl_deliver {
	if (obj.hits > 0) {
		set resp.http.X-vCache = "HIT";
	} else {
		set resp.http.X-vCache = "MISS";
	}
        unset resp.http.X-Req-Host;
        unset resp.http.X-Req-URL;
        unset resp.http.X-Req-URL-Base;

}
sub vcl_synth {
  if (resp.status == 750) {
    set resp.status = 301;
    set resp.http.Location = req.http.x-redir;
    return(deliver);
  }
}
