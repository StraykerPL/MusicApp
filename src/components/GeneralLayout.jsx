import { StyleSheet, View } from "react-native";

export default function GeneralLayout(props) {
    return(
        <View style={componentStyles}>
            {props.children}
        </View>
    );
}

const componentStyles = StyleSheet.create({
    container: {
        display: 'flex',
        flexDirection: "column",
        alignItems: 'center',
        justifyContent: 'center',
    },
});