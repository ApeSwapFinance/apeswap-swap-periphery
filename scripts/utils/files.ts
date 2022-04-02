import fs from 'fs';
import path from 'path';
import moment from 'moment';

export const getCurrentDirectoryBase = (): string => {
	return path.basename(process.cwd());
};

export const directoryExists = (filePath: string): boolean => {
	return fs.existsSync(filePath);
};

/**
 * Read a local json file and return a JS object.
 * 
 * @param filePath Path of the file (Do not include '.json')
 * @returns 
 */
export const readJSONFile = async (filePath: string): Promise<any> => {
	try {
		const buffer = await fs.promises.readFile(filePath + '.json', 'utf8');
		return JSON.parse(buffer);
	} catch (e) {
		throw new Error(`Error reading ${filePath}: ${e}`);
	}
};

/**
 * Save a JS object to a local json file.
 * 
 * @param fileName Name of the file (Do not include '.json')
 * @param data Object to write to file
 */
export const writeJSONToFile = async (
	fileName: string,
	data: {}
): Promise<void> => {
	try {
		await fs.promises.writeFile(fileName + '.json', JSON.stringify(data, null, 4));
	} catch (e) {
		console.error(`Error writing ${fileName}: ${e}`);
	}
};

/**
 * Appends "-YYYY-MM-DD" to the fileName.
 * 
 * @param fileName Name of the file (Do not include '.json')
 * @param data Object to write to file
 */
export const writeJSONToFileWithDate = async (
	fileName: string,
	data: {}
): Promise<void> => {
	const fileNameWithDate = `${fileName}-${moment().format('YYYY-MM-DD')}`
	await writeJSONToFile(fileNameWithDate, data);
};