package com.blaze.android.agent.util;

import java.io.IOException;
import java.io.Writer;
import java.util.Iterator;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

/**
 * Utility class for serializing JSON Objects in a memory-efficient manner
 * 
 * @author Joshua Tessier
 */
public final class JSONUtil {
	private static final String FALSE = "false";
	private static final String TRUE = "true";
	private static final String NULL = "null";
	private static final String SEPARATOR = ",";
	private static final String COLON = ":";
	private static final String CLOSE_ARRAY = "]";
	private static final String OPEN_ARRAY = "[";
	private static final String CLOSE_OBJECT = "}";
	private static final String OPEN_OBJECT = "{";

	private JSONUtil() {}
	
	/**
	 * Writes the object, and all of it's children, to the stream.
	 * 
	 * @param writer
	 * @param object
	 * @throws IOException
	 */
	@SuppressWarnings("rawtypes")
	public static void writeJSONObject(Writer writer, JSONObject object) throws JSONException, IOException {
		writer.write(OPEN_OBJECT);
		
		Iterator keys = object.keys();
		if (keys != null) {
			String key;
			while (keys.hasNext()) {
				key = (String)keys.next();

				writer.write(JSONObject.quote(key));
				writer.write(COLON);
				writeJSONValue(writer, object.get(key));
				if (keys.hasNext()) {
					writer.write(SEPARATOR);
				}
				
				//FLush, don't hold much
				writer.flush();
			}
		}
		
		writer.write(CLOSE_OBJECT);
	}
	
	/**
	 * WRites the entire array to the writer
	 * 
	 * @param writer
	 * @param array
	 * @throws IOException
	 */
	public static void writeJSONArray(Writer writer, JSONArray array) throws JSONException, IOException {
		writer.write(OPEN_ARRAY);
		
		int size = array.length();
		for (int i=0; i<size; ++i) {
			writeJSONValue(writer, array.get(i));
			if ((i + 1) < size) {
				writer.write(SEPARATOR);
			}
		}
		
		writer.write(CLOSE_ARRAY);
	}
	
	/**
	 * Writes the value to the writer
	 * 
	 * @param writer
	 * @param object
	 */
	public static void writeJSONValue(Writer writer, Object object) throws IOException, JSONException {
		//A value can be:
		//1) A string [ Needs quotes, must support unicode }
		//2) A number { Integer, Double, Scientific Notation }
		//3) A JSON Object
		//4) A JSON Array
		//5) The values 'true', 'false' or 'null'
		
		if (object == null) {
			writer.write(NULL);
		}
		else if (object instanceof String) {
			writer.write(JSONObject.quote((String)object));
		}
		else if (object instanceof Number) {
			writer.write(JSONObject.numberToString((Number)object));
		}
		else if (object instanceof JSONObject) {
			writeJSONObject(writer, (JSONObject)object);
		}
		else if (object instanceof JSONArray) {
			writeJSONArray(writer, (JSONArray)object);
		}
		else if (object instanceof Boolean) {
			Boolean value = (Boolean)object;
			if (value.booleanValue()) {
				writer.write(TRUE);
			}
			else {
				writer.write(FALSE);
			}
		}
	}
}
