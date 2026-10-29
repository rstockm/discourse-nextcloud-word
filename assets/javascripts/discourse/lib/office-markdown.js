export function markdownLink(result) {
  const label = result.file_name.replace(/[\\`*_[\]<>]/g, "\\$&");
  return `[${label}](${result.url})`;
}
