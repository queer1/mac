require 'formula'

class Multitail < Formula
  homepage 'http://www.vanheusden.com/multitail/download.html'
  url 'http://www.vanheusden.com/multitail/multitail-5.2.13.tgz'
  sha1 '1c4216929612cbad68855520b3a677be4c0c3713'

  def patches
  	DATA
  end
  
  def install
    ENV['DESTDIR'] = prefix
    system "make", "-f", "makefile.macosx", "multitail"

    bin.install "multitail"
    man1.install gzip("multitail.1")
    etc.install "multitail.conf"
  end
end

__END__
diff -u ../multitail-5.2.13-orig/error.c ./error.c
--- ../multitail-5.2.13-orig/error.c	2013-06-19 11:22:09.000000000 -0700
+++ ./error.c	2013-07-12 17:11:06.000000000 -0700
@@ -8,7 +8,7 @@
 #include <stdlib.h>
 #include <signal.h>
 #include <regex.h>
-#if defined(__GLIBC__)
+#if defined (__GLIBC__) || defined (__APPLE__)
 #include <execinfo.h>
 #endif
 #include <sys/socket.h>
@@ -21,7 +21,7 @@
 void error_exit_(char *file, const char *function, int line, char *format, ...)
 {
 	va_list ap;
-#if defined(__GLIBC__)
+#if defined (__GLIBC__) || defined (__APPLE__)
 	int index;
         void *trace[128];
         int trace_size = backtrace(trace, 128);
@@ -46,7 +46,7 @@
 	fprintf(stderr, "This problem occured at line %d in function %s (from file %s):\n", line, function, file);
 	if (errno) fprintf(stderr, "errno variable was then: %d which means \"%s\"\n", errno, strerror(errno));
 	fprintf(stderr, "Binary build at %s %s\n", __DATE__, __TIME__);
-#if defined(__GLIBC__)
+#if defined(__GLIBC__) || defined (__APPLE__)
         fprintf(stderr, "Execution path:\n");
         for(index=0; index<trace_size; ++index)
                 fprintf(stderr, "\t%d %s\n", index, messages[index]);
diff -u ../multitail-5.2.13-orig/mt.c ./mt.c
--- ../multitail-5.2.13-orig/mt.c	2013-06-19 11:22:09.000000000 -0700
+++ ./mt.c	2013-07-12 17:07:02.000000000 -0700
@@ -1882,7 +1882,7 @@
 	lb[f_index].maxnlines = maxnlines;
 }
 
-char close_window(int winnr, proginfo *cur)
+char close_window_helper(int winnr, proginfo *cur, mybool_t stopProcess)
 {
 	if (winnr == terminal_main_index)
 	{
@@ -1891,7 +1891,10 @@
 	}
 
 	/* make sure it is really gone */
-	stop_process(cur -> pid);
+	if (stopProcess == 1)
+	{
+		stop_process(cur -> pid);
+	}
 
 	/* restart window? */
 	if (cur -> restart.restart >= 0)
@@ -1978,6 +1981,17 @@
 	}
 }
 
+/* OSX: use with false if we do not want to send TERM signals to the process, like if we got the pid from a wait already */
+char close_window_for_dead_process(int winnr, proginfo *cur) {
+	return close_window_helper(winnr, cur, 0);
+}
+char close_window_and_stop_process(int winnr, proginfo *cur) {
+	return close_window_helper(winnr, cur, 1 );
+}
+char close_window(int winnr, proginfo *cur) {
+	return close_window_helper(winnr, cur, 1 );
+}
+
 void do_restart_window(proginfo *cur)
 {
 	/* stop process */
@@ -2874,7 +2888,7 @@
 				/* did it exit? */
 				if (died_proc == cur -> pid && cur -> wt != WT_STDIN && cur -> wt != WT_SOCKET)
 				{
-					int refresh_info = close_window(f_index, cur);
+					int refresh_info = close_window_for_dead_process(f_index, cur);
 
 					found = a_window_got_closed = 1;
 
@@ -3590,6 +3604,9 @@
 
 			if (check_for_died_processes())
 			{
+				if (!do_not_close_closed_windows && terminal_index == NULL) {
+					do_exit();
+				}
 				c = -1;
 				break;
 			}
@@ -3607,6 +3624,9 @@
 
 		if (deleted_entry_in_array >= 0)
 		{
+			if (!do_not_close_closed_windows && terminal_index == NULL) {
+				do_exit();
+			}
 			c = -1;
 			break;
 		}
diff -u ../multitail-5.2.13-orig/utils.c ./utils.c
--- ../multitail-5.2.13-orig/utils.c	2013-06-19 11:22:09.000000000 -0700
+++ ./utils.c	2013-07-12 17:12:11.000000000 -0700
@@ -184,10 +184,14 @@
 {
 	assert(pid > 1);
 
-	if (mykillpg(pid, SIGTERM) == -1)
+	if (mykillpg(pid, SIGTERM) == -1 && errno != ESRCH)
 	{
-		if (errno != ESRCH)
-			error_exit("Problem stopping child process with PID %d (SIGTERM).\n", pid);
+		if (errno == EINVAL)
+			error_exit("Bad signal when stopping child process with PID %d (SIGTERM).\n", pid);
+#ifndef __APPLE__
+		else if (errno == EPERM)
+			error_exit("Bad permissions stopping child process with PID %d (SIGTERM).\n", pid);
+#endif
 	}
 
 	usleep(1000);
@@ -205,9 +209,14 @@
 				error_exit("Problem stopping child process with PID %d (SIGKILL).\n", pid);
 		}
 	}
-	else if (errno != ESRCH)
-		error_exit("Problem stopping child process with PID %d (SIGTERM).\n", pid);
-
+	else if (errno == EINVAL)
+		error_exit("Bad signal when verifying child process stopped with PID %d (SIGTERM).\n", pid);
+#ifndef __APPLE__
+	else if (errno == EPERM)
+			error_exit("Bad permissions verifying child process stopped with PID %d (SIGTERM).\n", pid);
+#endif
+	// not worried about ESRCH
+	
 	/* wait for the last remainder of the died process to go away,
 	 * otherwhise we'll find zombies on our way
 	 */
