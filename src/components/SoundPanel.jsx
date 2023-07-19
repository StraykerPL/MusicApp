import { Button, StyleSheet, Text, View } from "react-native";

export default function SoundPanel(props) {
    return(
        <View style={componentStyles.soundPanel}>
            <View style={componentStyles.soundPanel.metaData}>
                <Text>{props.musicName}</Text>
                <Text>{props.musicAuthor}</Text>
            </View>
            <View style={componentStyles.soundPanel.controlButtons}>
                <Button title="Play" />
                <Button title="Pause" />
            </View>
        </View>
    );
}

const componentStyles = StyleSheet.create({
    soundPanel: {
        width: 300,
        height: 75,
        display: "flex",
        flexDirection: "row",
        justifyContent: "space-between",
        alignItems: "center",
        paddingRight: 20,
        paddingLeft: 20,
        backgroundColor: "lightblue",
        metaData: {
            display: "flex",
            flexDirection: "column",
        },
        controlButtons: {
            display: "flex",
            flexDirection: "row"
        }
    }
});