import ModalController from "discourse/controllers/modal";

export default ModalController.extend({
  fileName: null,
  isLoading: false,

  onShow() {
    this.set("fileName", this.model.fileName);
  },

  updateFileName(event) {
    this.set("fileName", event.target.value);
  },

  handleKeyDown(event) {
    if (event.key === "Enter" && !this.isLoading) {
      this.confirm();
    }
  },

  confirm() {
    if (this.isLoading) return;
    
    const fileName = this.fileName?.trim();
    if (!fileName) {
      this.dialog.alert("Please enter a file name.");
      return;
    }

    // Endung sicherstellen
    const fileType = this.model.fileType;
    const finalFileName = fileName.endsWith(`.${fileType}`) 
      ? fileName 
      : `${fileName}.${fileType}`;

    this.set("isLoading", true);
    
    // Callback aufrufen
    this.model.onConfirm(finalFileName);
    
    // Modal schließen
    this.send("closeModal");
  },

  cancel() {
    if (this.isLoading) return;
    this.send("closeModal");
  }
});
