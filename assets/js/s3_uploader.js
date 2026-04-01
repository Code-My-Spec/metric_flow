// S3 presigned URL uploader for Phoenix LiveView external uploads.
//
// Usage: Add to your LiveSocket configuration:
//
//   import { S3Uploader } from "./s3_uploader"
//   let liveSocket = new LiveSocket("/live", Socket, {
//     uploaders: { S3: S3Uploader },
//     ...
//   })

export const S3Uploader = (entries, onViewError) => {
  entries.forEach((entry) => {
    const { url, s3_key } = entry.meta

    const xhr = new XMLHttpRequest()
    onViewError(() => xhr.abort())

    xhr.onload = () => {
      if (xhr.status >= 200 && xhr.status < 300) {
        entry.progress(100)
        entry.done()
      } else {
        entry.error(`Upload failed with status ${xhr.status}`)
      }
    }

    xhr.onerror = () => entry.error("Upload failed")

    xhr.upload.addEventListener("progress", (event) => {
      if (event.lengthComputable) {
        const percent = Math.round((event.loaded / event.total) * 100)
        if (percent < 100) {
          entry.progress(percent)
        }
      }
    })

    xhr.open("PUT", url, true)
    xhr.setRequestHeader("content-type", entry.file.type)
    xhr.send(entry.file)
  })
}
