/**
 * asyncForEach is a helper method for performing a foreach loop on an array asynchronously
 * @param array
 * @param callback
 */
export async function asyncForEach<T>(
  array: Array<T>,
  callback: (item: T, index: number) => void,
): Promise<void> {
  for (let index = 0; index < array.length; index++) {
    await callback(array[index], index)
  }
}
