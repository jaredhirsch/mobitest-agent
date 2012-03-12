/*
 * Blaze Android Agent
 * 
 * Copyright Blaze 2010
 */
package com.blaze.android.agent.managers;

import java.io.DataOutputStream;
import java.io.IOException;
import java.util.Vector;

import android.util.Log;

/**
 * Singleton used to manage the pcap2har python script and tcpdump.
 * 
 * @author Joshua Tessier
 * 
 */
public final class ProcessManager {
	private static final String PROCESS_MANAGER = "ProcessManager";

	private static ProcessManager instance;

	private Process tcpDumpProcess;
	private DataOutputStream tcpDumpOutputStream;

	private ProcessManager() {
	}

	public synchronized static ProcessManager getInstance() {
		if (instance == null) {
			instance = new ProcessManager();
		}
		return instance;
	}

	/**
	 * Returns true if we have root access
	 * 
	 * @return
	 */
	public boolean testRootPermissions() {
		boolean rootAccess = false;
		try {
			Process rootProcess = Runtime.getRuntime().exec("su");

			Log.i(PROCESS_MANAGER, "Testing root permissions");

			DataOutputStream os = new DataOutputStream(rootProcess.getOutputStream());
			try {
				// Write to a location that is usually root-protected, this will trigger su to actually do something and cause a request for root permissions to appear.
				// If we accept, it'll be permanently saved (or if we prompt, then this app simply won't work properly)
				os.writeBytes("echo \"Root Test\" >/system/sd/temporary.txt\n");
				os.writeBytes("exit\n");
				os.flush();
				rootProcess.waitFor();

				if (rootProcess.exitValue() != 255) {
					rootAccess = true;
					Log.i(PROCESS_MANAGER, "Root access granted");
				}
				else {
					Log.e(PROCESS_MANAGER, "Root access denied");
				}
			}
			catch (InterruptedException e) {
				Log.e(PROCESS_MANAGER, "Root access denied");
			}
			finally {
				if (os != null) {
					os.close();
				}
			}
		}
		catch (IOException e) {
			Log.e(PROCESS_MANAGER, "Root access denied");
		}
		return rootAccess;
	}

	public void deleteFiles(Vector<String> paths) {
		try {
			Process rootProcess = Runtime.getRuntime().exec("su");
			Log.i(PROCESS_MANAGER, "Deleting files as root");

			DataOutputStream os = new DataOutputStream(rootProcess.getOutputStream());
			try {
				// Delete each file
				for (String path : paths) {
					Log.v(PROCESS_MANAGER, "Removing file");
					try {
						os.writeBytes("rm -rf " + path + "\n");
					}
					catch (Exception e) {
						Log.e(PROCESS_MANAGER, "Failed to write rm command for file " + path, e);
					}
				}
				os.writeBytes("exit\n");
				os.flush();
				rootProcess.waitFor();
			}
			catch (InterruptedException e) {
				Log.e(PROCESS_MANAGER, "Root access denied");
			}
			finally {
				if (os != null) {
					os.close();
				}
			}
		}
		catch (IOException e) {
			Log.e(PROCESS_MANAGER, "Root access denied");
		}
	}

	public void startNetworkMonitor(String path, String tcpdumpInterface, String prio) {
		try {
			Log.i(PROCESS_MANAGER, "Starting TCPDUMP");
			tcpDumpProcess = Runtime.getRuntime().exec("su");
			tcpDumpOutputStream = new DataOutputStream(tcpDumpProcess.getOutputStream());
			if (tcpdumpInterface == null || tcpdumpInterface.length() == 0) {
				Log.i(PROCESS_MANAGER, "TCPDUMP: No network interface specified (tcpdump -v -s 0 -w " + path + "\n" + ")");
				tcpDumpOutputStream.writeBytes("tcpdump -v -p -n -s 0 -w " + path + "\n");
			}
			else {
				Log.i(PROCESS_MANAGER, "TCPDUMP: " + tcpdumpInterface + " interface specified (tcpdump -v -i " + tcpdumpInterface + " -s 0 -w " + path + "\n" + ")");
				tcpDumpOutputStream.writeBytes("tcpdump -v -p -n -i " + tcpdumpInterface + " -s 0 -w " + path + "\n");
			}
			Log.i(PROCESS_MANAGER, "Starting to tcpdump: " + path);
		}
		catch (IOException e) {
			Log.e(PROCESS_MANAGER, "Failed to start tcpdump", e);
		}
	}

	public void stopNetworkMonitor() {
		try {
			try {
				tcpDumpProcess.destroy();
			}
			finally {
				if (tcpDumpOutputStream != null) {
					tcpDumpOutputStream.close();
				}
			}
		}
		catch (IOException e) {
			Log.e(PROCESS_MANAGER, "Failed to close");
		}

		// Now kill off any errant tcpdump process...i.
		// TODO: Find a better way to do this
		try {
			Process killAll = Runtime.getRuntime().exec("su");
			DataOutputStream dos = null;
			try {
				dos = new DataOutputStream(killAll.getOutputStream());
				dos.writeBytes("kill `pgrep tcpdump | grep -v $$ | tr '\n' ' '`\n");
				dos.writeBytes("exit\n");
				dos.flush();
				killAll.waitFor();
				if (killAll.exitValue() != 255) {
					Log.i(PROCESS_MANAGER, "tcpdumps terminated");
				}
				else {
					Log.e(PROCESS_MANAGER, "FAILED TO CLOSE TCPDUMP -- ERRANT PROCESS ALERT!!!!");
				}
			}
			catch (IOException e) {
				Log.e(PROCESS_MANAGER, "Failed to kill tcpdump cleanly", e);
			}
			catch (InterruptedException e) {
				Log.e(PROCESS_MANAGER, "Failed to kill tcpdump cleanly", e);
			}
		}
		catch (IOException e) {
			Log.e(PROCESS_MANAGER, "Failed to kill tcpdump cleanly", e);
		}
	}
}
