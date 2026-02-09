export function isCategoryExcluded(siteSettings, categoryId) {
  const excluded = siteSettings.topic_gallery_excluded_categories;
  if (!excluded) {
    return false;
  }
  return excluded.split("|").includes(String(categoryId));
}
