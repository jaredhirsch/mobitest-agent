/*
 * Blaze Android Agent
 * 
 * Copyright Blaze 2010
 */
package com.blaze.android.agent.managers;

import java.io.BufferedReader;
import java.io.DataOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.List;
import java.util.Vector;
import java.util.regex.Pattern;

import com.blaze.android.agent.Constants;

import android.util.Log;

/**
 * Singleton used to manage the pcap2har python script and tcpdump.
 * 
 * @author Joshua Tessier
 * 
 */
public final class ProcessManager {
  private static final String PROCESS_MANAGER = "ProcessManager";
  private static final Pattern whitespace = Pattern.compile("\\s+");

  private static ProcessManager instance;

  private Process tcpDumpProcess;
  private DataOutputStream tcpDumpOutputStream;
  private String autodetectedNetworkInterface = null;

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
  
  /**
   * Returns the single interface that's 1) non-local, 2) UP, 3) has IP other than 0.0.0.0, on null.
   */
  private synchronized String autodetectNetworkInterface() {
    if (autodetectedNetworkInterface == null) {
      autodetectedNetworkInterface = "";  // Start with an empty string to avoid retrying on failure
      try {
        Log.i(PROCESS_MANAGER, "Running netcfg to autodetect network interface");
        Process netcfgProcess = Runtime.getRuntime().exec(new String[] {"netcfg"});
        netcfgProcess.getOutputStream().close();
        int exitCode = netcfgProcess.waitFor();
        List<String> stdoutLines = readLines(netcfgProcess.getInputStream());
        List<String> stderrLines = readLines(netcfgProcess.getErrorStream());
        netcfgProcess.getInputStream().close();
        netcfgProcess.getErrorStream().close();
        if (exitCode == 0 && stderrLines.isEmpty()) {
          for (String line : stdoutLines) {
            String[] fields = whitespace.split(line.trim());
            if (fields.length != 5) {
              throw new IOException("netcfg output not recognized: " + line);
            }
            if (!fields[0].equals("lo") && fields[1].equals("UP") && !fields[2].equals("0.0.0.0")) {
            	autodetectedNetworkInterface = fields[0];
              break;
            }
          }
        } else {  
          Log.e(PROCESS_MANAGER,
          		"netcfg failed: exit code " + exitCode + ", stderr: " + stderrLines);
        }
      } catch (IOException e) {
        Log.e(PROCESS_MANAGER, "Error autodetectiong network interface: " + e, e);
      } catch (InterruptedException e) {
        Log.e(PROCESS_MANAGER, "Autodetecting network interface interrupted", e);
        Thread.currentThread().interrupt();
      }
    }
  	// Empty string means detection ran and failed.
  	return autodetectedNetworkInterface.isEmpty() ? null : autodetectedNetworkInterface;
  }
  
  private List<String> readLines(InputStream stream) throws IOException {
    BufferedReader reader = new BufferedReader(new InputStreamReader(stream));
    List<String> lines = new ArrayList<String>();
    for(String line = reader.readLine(); line != null; line = reader.readLine()) {
      lines.add(line);
    }
    return lines;
  }

  public synchronized void startNetworkMonitor(String path, String tcpdumpInterface, String prio) {
    StringBuilder tcpdumpCommandBuilder = new StringBuilder();
    tcpdumpCommandBuilder.append(Constants.CAPTURE_TCPDUMP).append(" -v -p -n ");
    if (tcpdumpInterface == null || tcpdumpInterface.length() == 0) {
      // If network interface is not forced via a preference, try to autodetect it.
      tcpdumpInterface = autodetectNetworkInterface();
    }
    if (tcpdumpInterface == null || tcpdumpInterface.length() == 0) {
      Log.i(PROCESS_MANAGER, "TCPDUMP: No network interface specified.");
    } else {
      tcpdumpCommandBuilder.append(" -i ").append(tcpdumpInterface);
    }
    tcpdumpCommandBuilder.append(" -s 0 -w ").append(path).append("\n");
    String tcpdumpCommand = tcpdumpCommandBuilder.toString();
    Log.i(PROCESS_MANAGER, "tcpdump cmd: "+ tcpdumpCommand);

    try {
      Log.i(PROCESS_MANAGER, "Starting TCPDUMP");
      tcpDumpProcess = Runtime.getRuntime().exec("su");
      tcpDumpOutputStream = new DataOutputStream(tcpDumpProcess.getOutputStream());
      tcpDumpOutputStream.writeBytes(tcpdumpCommand);
    }
    catch (IOException e) {
      Log.e(PROCESS_MANAGER, "Failed to start tcpdump", e);
    }
  }

  public synchronized void stopNetworkMonitor() {
  	killTcpdumpIfRunning();
  	killStrayTcpdumps();
  }
  
  private synchronized void killTcpdumpIfRunning() {
  	if (tcpDumpProcess != null) {
      boolean alreadyExited = false;
      try {
        int exitCode = tcpDumpProcess.exitValue();
        alreadyExited = true;
        List<String> stdoutLines = readLines(tcpDumpProcess.getInputStream());
        List<String> stderrLines = readLines(tcpDumpProcess.getErrorStream());
        Log.i(PROCESS_MANAGER, "tcpdump exited prematurely with code " + exitCode +
            ", stdout: " + stdoutLines + " stderr: " + stderrLines);
      } catch (IllegalThreadStateException e) {
        // Process has not yet exited -- this is what we expect, so just continue
      } catch (IOException e) {
        Log.e(PROCESS_MANAGER, "Error while getting stdout/stderr of a failed tcpdump", e);
      }
      if (!alreadyExited) {
        // TODO: Instead run a shell kill command and wait for tcpdump exit, otherwise truncates pcap.
        // Unify this with the kill command code below.
        // Move errant tcpdump killing to startNetworkMonitoring.
        tcpDumpProcess.destroy();
        if (tcpDumpOutputStream != null) {
          try {
            tcpDumpOutputStream.close();
          } catch (IOException e) {
            Log.e(PROCESS_MANAGER, "Failed to close tcpDumpOutputStream", e);
          }
        }
      }
      tcpDumpProcess = null;
      tcpDumpOutputStream = null;
  	}
  }

  private synchronized void killStrayTcpdumps() {
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
          Log.i(PROCESS_MANAGER, "stray tcpdumps terminated");
        }
        else {
          Log.e(PROCESS_MANAGER, "FAILED TO CLOSE su kill -- ERRANT PROCESS ALERT!!!!");
        }
      }
      catch (IOException e) {
        Log.e(PROCESS_MANAGER, "Failed to kill stray tcpdumps cleanly", e);
      }
      catch (InterruptedException e) {
        Log.e(PROCESS_MANAGER, "Failed to kill stray tcpdumps cleanly", e);
      }
    }
    catch (IOException e) {
      Log.e(PROCESS_MANAGER, "Failed to kill stray tcpdumps cleanly", e);
    }
  }
}
